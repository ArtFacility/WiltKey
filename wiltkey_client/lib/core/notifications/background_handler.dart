import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed25519;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';
import 'pending_inbox.dart';

// Outer WebSocket content types that represent an actual user message worth a
// "you got a message" alert. Control frames (receipts, resync, borrow, metadata,
// nuke, emoji defs) are still buffered for replay but never raise a notification.
const Set<String> _notifyContentTypes = {'text', 'image', 'group_message'};

const _secure = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

class _BgCreds {
  final String relayUrl;
  final String userId;
  final String pubKeyHex;
  final String privKeyHex;
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
  return _BgCreds(relay, userId, pub, priv);
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
    _creds = await _loadCreds();
    await _connect();
  }

  // Periodic watchdog: re-open the socket if it dropped.
  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_socket == null && !_connecting) {
      _connect();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
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
          final sig = _sign(creds.privKeyHex, challenge);
          _socket?.add(
            jsonEncode({
              'type': 'AUTH',
              'pubkey': creds.pubKeyHex,
              'signature': sig,
            }),
          );
          break;
        case 'AUTH_OK':
          // Authenticated; the server will now stream queued + live frames.
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
          if (_notifyContentTypes.contains(contentType)) {
            // sender_id is the 1:1 peer's keyHash, enabling a deep-link on tap.
            // (Group frames carry a member id, which won't resolve to a chat —
            // those simply fall back to the dashboard.)
            WiltkeyNotifications.showMessageNotification(chatKey: senderId);
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

// =============================================================================
// LOW POWER MODE — periodic queue/status poll (WorkManager)
// =============================================================================

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kLowPowerTaskName) return true;
    try {
      final creds = await _loadCreds();
      if (creds != null) {
        final hasPayload = await _pollQueueStatus(creds);
        if (hasPayload) {
          await WiltkeyNotifications.initLocalNotifications();
          await WiltkeyNotifications.showMessageNotification();
        }
      }
    } catch (_) {
      // Swallow — a failed poll should not disable future runs.
    } finally {
      // Self-reschedule so polling keeps cycling (~10 min) while the mode is
      // still Low Power. Cancelled by the main isolate when the app returns to
      // the foreground.
      await _rescheduleIfLowPower();
    }
    return true;
  });
}

Future<bool> _pollQueueStatus(_BgCreds creds) async {
  final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
  final sig = _sign(creds.privKeyHex, '${creds.userId}:$ts');
  final base = Uri.parse(creds.relayUrl);
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
    final resp = await req.close().timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) return false;
    final body = await resp.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['has_payload'] == true;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

Future<void> _rescheduleIfLowPower() async {
  final prefs = await SharedPreferences.getInstance();
  final mode = NotificationMode.fromStorage(
    prefs.getString(kPrefNotificationMode),
  );
  if (mode != NotificationMode.lowPower) return;
  await Workmanager().registerOneOffTask(
    kLowPowerTaskUnique,
    kLowPowerTaskName,
    initialDelay: kLowPowerInterval,
    existingWorkPolicy: ExistingWorkPolicy.replace,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}
