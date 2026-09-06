import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed25519;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../network/pow_solver.dart';
import 'notification_service.dart';
import 'pending_inbox.dart';

// Outer WebSocket content types that represent an actual user message worth a
// "you got a message" alert. Control frames (receipts, resync, borrow, metadata,
// nuke, emoji defs) are still buffered for replay but never raise a notification.
const Set<String> _notifyContentTypes = {
  'text',
  'image',
  'voice',
  'group_message',
  'emergency_chat',
};

const _secure = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

class _BgCreds {
  final String relayUrl;
  final String userId;
  final String pubKeyHex;
  final String privKeyHex;
  /// Relay-issued device token (raw) — read fresh from prefs on every load so
  /// a refresh that happened in the main isolate is picked up automatically.
  String? deviceToken;
  _BgCreds(this.relayUrl, this.userId, this.pubKeyHex, this.privKeyHex);
}

Future<_BgCreds?> _loadCreds() async {
  final prefs = await SharedPreferences.getInstance();
  final relay = prefs.getString(kPrefBgRelayUrl);
  final userId = prefs.getString(kPrefBgUserId);
  final pub = prefs.getString(kPrefBgPubKey);
  final priv = await _secure.read(key: kSecureSigningKey);
  if (relay == null || userId == null || pub == null || priv == null) {
    return null;
  }
  final creds = _BgCreds(relay, userId, pub, priv);
  creds.deviceToken = prefs.getString(kPrefDeviceToken);
  return creds;
}

Future<void> _storeDeviceToken(String? token) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(kPrefDeviceToken);
    } else {
      await prefs.setString(kPrefDeviceToken, token);
    }
  } catch (_) {}
}

List<int> _hexToBytes(String hex) {
  final bytes = <int>[];
  for (int i = 0; i + 1 < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return bytes;
}

String _bytesToHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

String _sign(String privKeyHex, String message) {
  final pk = ed25519.PrivateKey(_hexToBytes(privKeyHex));
  return _bytesToHex(ed25519.sign(pk, utf8.encode(message)));
}

String _wsUrl(String httpUrl) {
  final uri = Uri.parse(httpUrl);
  final scheme = (uri.scheme == 'https') ? 'wss' : 'ws';
  final path = uri.path.endsWith('/') ? '${uri.path}ws' : '${uri.path}/ws';
  return uri.replace(scheme: scheme, path: path).toString();
}

// =============================================================================
// INSTANT MODE — foreground-service background WebSocket
// =============================================================================

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_MessageTaskHandler());
}

class _MessageTaskHandler extends TaskHandler {
  WebSocket? _socket;
  bool _connecting = false;
  _BgCreds? _creds;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await WiltkeyNotifications.initLocalNotifications();
    await _writeFgHeartbeat();
    _creds = await _loadCreds();
    await _connect();
  }

  // Periodic watchdog: refresh the heartbeat (so the backstop poll knows the
  // service is alive) and re-open the socket if it dropped.
  @override
  void onRepeatEvent(DateTime timestamp) {
    _writeFgHeartbeat();
    if (_socket == null && !_connecting) {
      _connect();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Clear the heartbeat so the backstop poll notices immediately that the
    // service is gone and starts delivering. `isTimeout` is the Android 15 6-hour
    // dataSync cap; the plugin has already stopped the service (no ANR), and the
    // backstop poll scheduled alongside Instant mode carries delivery until the
    // app is next foregrounded (which restarts the service).
    await _clearFgHeartbeat();
    await _close();
  }

  Future<void> _connect() async {
    if (_connecting) return;
    _connecting = true;
    try {
      _creds ??= await _loadCreds();
      final creds = _creds;
      if (creds == null) {
        _connecting = false;
        return;
      }
      final socket = await WebSocket.connect(
        _wsUrl(creds.relayUrl),
      ).timeout(const Duration(seconds: 15));
      _socket = socket;
      _connecting = false;
      socket.listen(
        (data) => _onData(data, creds),
        onError: (_) => _close(),
        onDone: _close,
        cancelOnError: true,
      );
    } catch (_) {
      _connecting = false;
      await _close();
    }
  }

  void _onData(dynamic data, _BgCreds creds) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      switch (msg['type']) {
        case 'CHALLENGE':
          final challenge = msg['challenge'] as String;
          // Token-aware auth, mirroring the main WS client: with a token the
          // signature covers challenge||token (challenge-bound); without one
          // we sign the bare challenge and answer the issuance PoW instead.
          final token = creds.deviceToken;
          final hasToken = token != null && token.isNotEmpty;
          final sig = _sign(creds.privKeyHex, hasToken ? '$challenge$token' : challenge);
          _socket?.add(
            jsonEncode({
              'type': 'AUTH',
              'pubkey': creds.pubKeyHex,
              'signature': sig,
              if (hasToken) 'device_token': token,
            }),
          );
          break;
        case 'TOKEN_CHALLENGE':
          final challenge = msg['challenge'] as String? ?? '';
          final difficulty = (msg['difficulty'] as num?)?.toInt() ?? 5;
          if (challenge.isEmpty) break;
          // One-time per install — a few seconds of hashing is fine here.
          solvePoW(
            challenge: challenge,
            payload: creds.pubKeyHex,
            difficulty: difficulty,
          ).then((nonce) {
            _socket?.add(jsonEncode({
              'type': 'AUTH_TOKEN_ISSUE',
              'pow_nonce': nonce,
            }));
          }).catchError((_) {});
          break;
        case 'AUTH_OK':
          // Persist a refreshed/issued token so the poll + main isolate stay
          // current. Creds are re-read from prefs on the next connect.
          final fresh = msg['device_token'] as String?;
          if (fresh != null && fresh.isNotEmpty) {
            creds.deviceToken = fresh;
            _storeDeviceToken(fresh);
          }
          break;
        case 'AUTH_REJECTED':
          if ((msg['message'] as String? ?? '') == 'token_invalid') {
            creds.deviceToken = null;
            _storeDeviceToken(null);
            _close(); // next repeat-event reconnect goes through issuance
          }
          break;
        case 'NEW_MESSAGE':
          final senderId = msg['sender_id'] as String? ?? '';
          final envelope = msg['envelope'] as String? ?? '';
          final contentType = msg['content_type'] as String? ?? 'text';
          // Buffer the raw frame so the main isolate can decrypt + store it on
          // unlock (the server has already removed it from the offline queue).
          PendingInbox.append(
            senderId: senderId,
            envelope: envelope,
            contentType: contentType,
          );
          // NOTE: no FILE_RECEIVED ack here. This isolate only buffers the frame
          // — it can't decrypt or persist it while the app is locked — so acking
          // would tell the relay to delete the only copy of a file we haven't
          // actually stored yet. The main isolate acks after it stores it.
          if (_notifyContentTypes.contains(contentType)) {
            // sender_id is the 1:1 peer's keyHash, enabling a deep-link on tap.
            // (Group frames carry a member id, which won't resolve to a chat —
            // those simply fall back to the dashboard.) An emergency-chat frame
            // gets the distinct "emergency chat" copy.
            if (contentType == 'emergency_chat') {
              WiltkeyNotifications.showEmergencyChatNotification(
                chatKey: senderId,
              );
            } else {
              WiltkeyNotifications.showMessageNotification(chatKey: senderId);
            }
          }
          break;
        case 'FILE_OFFER':
          // A large file is waiting on the relay. Nothing to buffer — because we
          // never ACK it, the relay re-offers it on the next connect, so the main
          // isolate will pick it up when the app is unlocked. Just raise the alert.
          final senderId = msg['sender_id'] as String? ?? '';
          final contentType = msg['content_type'] as String? ?? 'text';
          if (_notifyContentTypes.contains(contentType)) {
            if (contentType == 'emergency_chat') {
              WiltkeyNotifications.showEmergencyChatNotification(
                chatKey: senderId,
              );
            } else {
              WiltkeyNotifications.showMessageNotification(chatKey: senderId);
            }
          }
          break;
      }
    } catch (_) {}
  }

  Future<void> _close() async {
    final s = _socket;
    _socket = null;
    try {
      await s?.close();
    } catch (_) {}
  }
}

// --- Foreground-service heartbeat (shared between the two background isolates) --

Future<void> _writeFgHeartbeat() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kPrefFgHeartbeatMs, DateTime.now().millisecondsSinceEpoch);
  } catch (_) {}
}

Future<void> _clearFgHeartbeat() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kPrefFgHeartbeatMs, 0);
  } catch (_) {}
}

/// True if the Instant foreground service wrote a heartbeat recently — i.e. the
/// socket is up and delivering, so the backstop poll should stay silent.
Future<bool> _fgServiceAlive() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final hb = prefs.getInt(kPrefFgHeartbeatMs) ?? 0;
    if (hb == 0) return false;
    return DateTime.now().millisecondsSinceEpoch - hb < kFgHeartbeatFreshMs;
  } catch (_) {
    return false;
  }
}

// =============================================================================
// LOW POWER / BACKSTOP MODE — adaptive queue/status poll (WorkManager)
// =============================================================================

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kLowPowerTaskName) return true;
    bool foundMessage = false;
    bool fgAlive = false;
    bool tokenInvalid = false;
    try {
      // Stay silent while the Instant foreground service is alive — it's already
      // delivering, so polling here would only risk a duplicate alert and waste
      // battery. When its heartbeat is stale (killed / 6h dataSync timeout / OEM
      // battery-killer), take over delivery.
      fgAlive = await _fgServiceAlive();
      if (!fgAlive) {
        final creds = await _loadCreds();
        if (creds != null) {
          var result = await _pollQueueStatus(creds);
          if (result == _PollResult.tokenInvalid) {
            // Self-heal: mint a fresh token right here (the worker holds the
            // identity key), then retry the poll once — otherwise low-power
            // mode would silently miss notifications until the app is
            // foregrounded.
            if (await _issueTokenViaWS(creds)) {
              result = await _pollQueueStatus(creds);
            }
          }
          foundMessage = result == _PollResult.found;
          tokenInvalid = result == _PollResult.tokenInvalid;
          if (foundMessage) {
            await WiltkeyNotifications.initLocalNotifications();
            await WiltkeyNotifications.showMessageNotification();
          }
        }
      }
    } catch (_) {
      // Swallow — a failed poll should not disable future runs.
    } finally {
      await _rescheduleAdaptivePoll(
        foundMessage: foundMessage,
        fgAlive: fgAlive,
        tokenInvalid: tokenInvalid,
      );
    }
    return true;
  });
}

/// One-shot WS connect that walks the token issuance gate (tokenless AUTH →
/// TOKEN_CHALLENGE → PoW → AUTH_TOKEN_ISSUE → AUTH_OK) and persists the minted
/// token. Used by the low-power worker when its stored token has gone invalid.
Future<bool> _issueTokenViaWS(_BgCreds creds) async {
  WebSocket? socket;
  try {
    socket = await WebSocket.connect(_wsUrl(creds.relayUrl))
        .timeout(const Duration(seconds: 15));
    final challenge = await socket
        .firstWhere((d) =>
            (jsonDecode(d as String) as Map<String, dynamic>)['type'] ==
            'CHALLENGE')
        .timeout(const Duration(seconds: 15));
    final ch = jsonDecode(challenge as String) as Map<String, dynamic>;
    final chHex = ch['challenge'] as String;
    socket.add(jsonEncode({
      'type': 'AUTH',
      'pubkey': creds.pubKeyHex,
      'signature': _sign(creds.privKeyHex, chHex),
    }));
    final tcRaw = await socket
        .firstWhere((d) =>
            (jsonDecode(d as String) as Map<String, dynamic>)['type'] ==
            'TOKEN_CHALLENGE')
        .timeout(const Duration(seconds: 15));
    final tc = jsonDecode(tcRaw as String) as Map<String, dynamic>;
    final nonce = await solvePoW(
      challenge: chHex,
      payload: creds.pubKeyHex,
      difficulty: (tc['difficulty'] as num?)?.toInt() ?? 5,
    ).timeout(const Duration(minutes: 5));
    socket.add(jsonEncode({'type': 'AUTH_TOKEN_ISSUE', 'pow_nonce': nonce}));
    final okRaw = await socket
        .firstWhere((d) =>
            (jsonDecode(d as String) as Map<String, dynamic>)['type'] ==
            'AUTH_OK')
        .timeout(const Duration(seconds: 15));
    final ok = jsonDecode(okRaw as String) as Map<String, dynamic>;
    final token = ok['device_token'] as String?;
    if (token == null || token.isEmpty) return false;
    creds.deviceToken = token;
    await _storeDeviceToken(token);
    return true;
  } catch (_) {
    return false;
  } finally {
    try {
      await socket?.close();
    } catch (_) {}
  }
}

  /// Poll outcomes the scheduler needs to react to.
  enum _PollResult { empty, found, tokenInvalid }

  Future<_PollResult> _pollQueueStatus(_BgCreds creds) async {
    final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final sig = _sign(creds.privKeyHex, '${creds.userId}:$ts');
    final base = Uri.parse(creds.relayUrl);
    final token = creds.deviceToken;
    final uri = base.replace(
      path: base.path.endsWith('/')
          ? '${base.path}api/v1/queue/status'
          : '${base.path}/api/v1/queue/status',
      queryParameters: {
        'id': creds.userId,
        'timestamp': ts,
        'sig': sig,
        'pubkey': creds.pubKeyHex,
      },
    );
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 20));
      // The raw token rides a HEADER, never the query string — query params
      // land in relay/nginx access logs verbatim.
      if (token != null && token.isNotEmpty) {
        req.headers.add('X-Device-Token', token);
      }
      final resp = await req.close().timeout(const Duration(seconds: 20));
      if (resp.statusCode == 403) {
        // Our token is dead/missing and this worker has no issuance path of
        // its own — clear it so the next foreground connect re-issues, and
        // tell the scheduler to hold the fast rung (this is NOT "no mail").
        await _storeDeviceToken(null);
        creds.deviceToken = null;
        return _PollResult.tokenInvalid;
      }
      if (resp.statusCode != 200) return _PollResult.empty;
      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['has_payload'] == true
          ? _PollResult.found
          : _PollResult.empty;
    } catch (_) {
      return _PollResult.empty;
    } finally {
      client.close(force: true);
    }
  }

// Re-enqueue the next poll on the adaptive ladder, if the app still wants it
// ([kPrefBgPollActive], cleared on foreground / mode off):
//   • fresh service heartbeat  → idle at the sparse rung (socket is delivering);
//   • a message was found       → snap back to the fast rung for catch-up;
//   • an empty poll             → step one rung sparser to save battery.
Future<void> _rescheduleAdaptivePoll({
  required bool foundMessage,
  required bool fgAlive,
  bool tokenInvalid = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool(kPrefBgPollActive) ?? false)) return;

  int index = prefs.getInt(kPrefLowPowerBackoffIndex) ?? 0;
  if (fgAlive) {
    index = kLowPowerBackoff.length - 1;
  } else if (foundMessage || tokenInvalid) {
    // A dead token is NOT "no mail" — hold the fast rung so delivery resumes
    // the moment the token self-heals (or the app is foregrounded).
    index = 0;
  } else {
    index = (index + 1).clamp(0, kLowPowerBackoff.length - 1);
  }
  await prefs.setInt(kPrefLowPowerBackoffIndex, index);

  await Workmanager().registerOneOffTask(
    kLowPowerTaskUnique,
    kLowPowerTaskName,
    initialDelay: lowPowerDelayForIndex(index),
    existingWorkPolicy: ExistingWorkPolicy.replace,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}
