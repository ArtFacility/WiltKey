import 'dart:io';
import 'dart:convert';
import 'dart:async';

class WebSocketClient {
  static final WebSocketClient _instance = WebSocketClient._internal();
  factory WebSocketClient() => _instance;

  WebSocketClient._internal();

  WebSocket? _socket;
  bool _isAuthenticated = false;
  bool _isConnecting = false;
  String? _currentUrl; // the URL we're actively trying right now
  String? _primaryUrl; // the user's configured relay (rotation anchor)
  String? _publicKeyHex;
  Timer? _reconnectTimer;
  int _connectionGeneration =
      0; // Tracks connection lifecycle to ignore stale events

  // --- Relay fallback ---
  // When the configured relay can't be reached after a few tries, rotate through
  // alternates (peer-advertised relays + the production default) so a stale/bad
  // saved relay doesn't strand the user offline. Supplied lazily by the app so
  // the candidate list always reflects the latest known peer relays.
  List<String> Function()? fallbackProvider;
  int _failCount = 0;
  int _rotationIndex = 0;
  static const int _failsBeforeFallback = 3;

  /// Ordered connection candidates: the user's primary first, then any
  /// app-provided fallbacks (deduped).
  List<String> get _candidates {
    final list = <String>[];
    if (_primaryUrl != null) list.add(_primaryUrl!);
    for (final f in (fallbackProvider?.call() ?? const <String>[])) {
      if (f.isNotEmpty && !list.contains(f)) list.add(f);
    }
    return list;
  }

  bool get isConnected => _socket != null && _isAuthenticated;

  // Stream controller to broadcast connection status updates
  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  // Injection Callbacks
  void Function(String message)? onLog;
  void Function(bool connected)? onStatusChanged;
  FutureOr<String> Function(String challenge)? onSignChallenge;
  void Function(String senderId, String envelope, String contentType)?
  onMessageReceived;
  void Function(Map<String, dynamic> message)? onRawMessageReceived;
  void Function(Map<String, dynamic> message)? onMessageSent;
  void Function(String spokeId)? onSpokeRequestOrder;
  void Function(int sequence)? onOrderConfirmed;
  void Function(String spokeId)? onSpokeCancelIntent;

  void _log(String msg) {
    if (onLog != null) {
      onLog!(msg);
    } else {
      print('[WebSocketClient] $msg');
    }
  }

  /// Connect to the user's configured relay. Resets fallback rotation so we
  /// always start from the primary preference.
  void connect(String httpUrl, {required String publicKeyHex}) {
    _publicKeyHex = publicKeyHex;
    _primaryUrl = httpUrl;
    _rotationIndex = 0;
    _failCount = 0;
    _attemptConnect(httpUrl);
  }

  void _attemptConnect(String httpUrl) {
    if (_isConnecting) return;
    _currentUrl = httpUrl;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectionGeneration++; // Invalidate all callbacks from previous connections
    final gen = _connectionGeneration;
    _closeSocket();

    _isConnecting = true;
    final wsUrl = _getWsUrl(httpUrl);
    _log('[WebSocket] Connecting to $wsUrl ... (gen=$gen)');

    WebSocket.connect(wsUrl)
        .then((socket) {
          if (gen != _connectionGeneration) {
            _log(
              '[WebSocket] Stale connection arrived (gen=$gen, current=$_connectionGeneration). Closing.',
            );
            socket.close();
            return;
          }

          _socket = socket;
          _isConnecting = false;
          _log('[WebSocket] Connected. Waiting for challenge...');

          socket.listen(
            (data) {
              _handleIncomingData(data);
            },
            onError: (err) {
              if (gen != _connectionGeneration) return;
              _log('[WebSocket] Error: $err');
              _handleDisconnect();
            },
            onDone: () {
              if (gen != _connectionGeneration) return;
              _log('[WebSocket] Connection closed by remote.');
              _handleDisconnect();
            },
            cancelOnError: true,
          );
        })
        .catchError((err) {
          if (gen != _connectionGeneration) return;
          _isConnecting = false;
          _log('[WebSocket] Connection failed: $err');
          _handleDisconnect();
        });
  }

  void _closeSocket() {
    final old = _socket;
    _socket = null;
    if (_isAuthenticated) {
      _isAuthenticated = false;
      _statusController.add(false);
      onStatusChanged?.call(false);
    }
    old?.close();
  }

  void _handleDisconnect() {
    if (_isConnecting) return;
    _closeSocket();
    _failCount++;

    // Default: retry the same URL. After a few straight failures, rotate to the
    // next candidate (peer-advertised relay / production default) so a bad saved
    // relay doesn't keep us offline. A working connection resets the counter.
    String next = _currentUrl ?? _primaryUrl ?? '';
    final cands = _candidates;
    if (_failCount >= _failsBeforeFallback && cands.length > 1) {
      _failCount = 0;
      _rotationIndex = (_rotationIndex + 1) % cands.length;
      next = cands[_rotationIndex];
      _log('[WebSocket] Relay $_currentUrl unreachable; falling back to $next');
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (next.isNotEmpty && _publicKeyHex != null) {
        _log('[WebSocket] Attempting auto-reconnect...');
        _attemptConnect(next);
      }
    });
  }

  void disconnect() {
    _currentUrl = null;
    _primaryUrl = null;
    _publicKeyHex = null;
    _failCount = 0;
    _rotationIndex = 0;
    _reconnectTimer?.cancel();
    _closeSocket();
  }

  void sendWSMessage(Map<String, dynamic> msgMap) {
    if (onMessageSent != null) {
      try {
        onMessageSent!(msgMap);
      } catch (e) {
        _log('[WebSocket Error] Error in onMessageSent callback: $e');
      }
    }
    if (_socket == null) {
      _log('[WebSocket] Cannot send message, socket is null');
      return;
    }
    _socket!.add(jsonEncode(msgMap));
  }

  /// Spoke requests a sequence number from the Host for group messaging.
  void sendRequestOrder(String hostId) {
    sendWSMessage({'type': 'REQUEST_ORDER', 'host_id': hostId});
  }

  /// Spoke cancels a previously requested order intent.
  void sendCancelIntent(String hostId) {
    sendWSMessage({'type': 'CANCEL_INTENT', 'host_id': hostId});
  }

  /// Host confirms a sequence number assignment to a spoke.
  void sendConfirmOrder(String spokeId, int sequence) {
    sendWSMessage({
      'type': 'CONFIRM_ORDER',
      'spoke_id': spokeId,
      'sequence': sequence,
    });
  }

  /// Host broadcasts individually-encrypted group message envelopes to all spokes.
  void sendBroadcastGroupMessage(
    List<String> recipientIds,
    Map<String, String> envelopes,
  ) {
    sendWSMessage({
      'type': 'BROADCAST_GROUP_MESSAGE',
      'recipients': recipientIds,
      'envelopes': envelopes,
    });
  }

  void _handleIncomingData(dynamic data) {
    try {
      final msgStr = data as String;
      final Map<String, dynamic> jsonMap = jsonDecode(msgStr);
      onRawMessageReceived?.call(jsonMap);
      final type = jsonMap['type'] ?? '';

      switch (type) {
        case 'CHALLENGE':
          final challenge = jsonMap['challenge'] as String;
          _authenticate(challenge);
          break;
        case 'AUTH_OK':
          _isAuthenticated = true;
          // A live connection clears the failure streak and pins rotation to the
          // relay that actually worked, so we stay put instead of drifting off it.
          _failCount = 0;
          final workingIdx = _candidates.indexOf(_currentUrl ?? '');
          if (workingIdx >= 0) _rotationIndex = workingIdx;
          _statusController.add(true);
          onStatusChanged?.call(true);
          final serverUserId = jsonMap['user_id'] as String;
          _log(
            '[WebSocket] Authentication successful! Server User ID: $serverUserId',
          );
          break;
        case 'NEW_MESSAGE':
          final senderId = jsonMap['sender_id'] as String;
          final envelope = jsonMap['envelope'] as String;
          final contentType = jsonMap['content_type'] ?? 'text';

          _log('[WebSocket] Received NEW_MESSAGE from $senderId');
          if (onMessageReceived != null) {
            onMessageReceived!(senderId, envelope, contentType);
          }
          break;
        case 'SPOKE_REQUEST_ORDER':
          final spokeId = jsonMap['spoke_id'] as String;
          _log('[WebSocket] Received SPOKE_REQUEST_ORDER from spoke: $spokeId');
          onSpokeRequestOrder?.call(spokeId);
          break;
        case 'ORDER_CONFIRMED':
          final sequence = jsonMap['sequence'] as int;
          _log('[WebSocket] Received ORDER_CONFIRMED, sequence: $sequence');
          onOrderConfirmed?.call(sequence);
          break;
        case 'SPOKE_CANCEL_INTENT':
          final spokeId = jsonMap['spoke_id'] as String;
          _log('[WebSocket] Received SPOKE_CANCEL_INTENT from spoke: $spokeId');
          onSpokeCancelIntent?.call(spokeId);
          break;
        case 'ERROR':
          _log('[WebSocket] Error from server: ${jsonMap['message']}');
          break;
        default:
          _log('[WebSocket] Unhandled message type: $type');
      }
    } catch (e) {
      _log('[WebSocket] Error processing incoming data: $e');
    }
  }

  Future<void> _authenticate(String challenge) async {
    if (_publicKeyHex == null || onSignChallenge == null) {
      _log(
        '[WebSocket Auth Error] Missing public key or sign challenge callback.',
      );
      return;
    }

    _log('[WebSocket] Responding to CHALLENGE...');
    final signatureHex = await onSignChallenge!(challenge);

    sendWSMessage({
      'type': 'AUTH',
      'pubkey': _publicKeyHex,
      'signature': signatureHex,
    });
  }

  String _getWsUrl(String httpUrl) {
    final uri = Uri.parse(httpUrl);
    final scheme = (uri.scheme == 'https') ? 'wss' : 'ws';
    final path = uri.path.endsWith('/') ? '${uri.path}ws' : '${uri.path}/ws';
    return uri.replace(scheme: scheme, path: path).toString();
  }
}
