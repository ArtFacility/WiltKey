import 'dart:io';
import 'dart:convert';
import 'dart:async';

class WebSocketClient {
  static final WebSocketClient _instance = WebSocketClient._internal();
  factory WebSocketClient() => _instance;

  WebSocketClient._internal();

  WebSocket? _socket;
  bool _isAuthenticated = false;
  // Whether the relay we're CURRENTLY connected to advertised group fan-out
  // (server-side broadcast). Per-connection: reset on every disconnect and set
  // from AUTH_OK, so switching to an older self-hosted relay falls back to the
  // per-member send loop instead of dropping messages into its `default:` case.
  bool _supportsGroupFanout = false;
  bool get supportsGroupFanout => _isAuthenticated && _supportsGroupFanout;
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
  /// The relay has a large payload waiting for us. [meta] is the message envelope
  /// with its ciphertext stripped (enough to place the message in a chat); the
  /// body must be fetched with [requestFile] before it can be decrypted.
  void Function(
    String senderId,
    String contentType,
    String messageId,
    String meta,
    int size,
  )?
  onFileOffer;

  /// A download token was issued (or refused, with [error] set) for [messageId].
  void Function(String messageId, String? token, String? error)? onFileToken;

  /// The relay URL currently connected to — the base for HTTP file downloads.
  String? get activeRelayUrl => _currentUrl;

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
      _supportsGroupFanout = false; // re-learned from the next AUTH_OK
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

  /// Ask the relay for a short-lived download token for a pending large file.
  /// The answer arrives as FILE_TOKEN (or FILE_ERROR) on [onFileToken].
  void requestFile(String messageId) {
    sendWSMessage({'type': 'REQUEST_FILE', 'message_id': messageId});
  }

  /// Ask the relay to re-advertise every un-ACKed large file it still holds for
  /// us. The live FILE_OFFER is the only delivery attempt while we stay
  /// connected, so a single missed frame (socket rotation, buffer eviction, a
  /// swallowed handler error) would otherwise hide the file until a full
  /// reconnect. Fire this on (re)auth and on foreground-resume; re-offers are
  /// idempotent (dedup by message id in _storeFileOffer).
  void requestPendingFiles() {
    sendWSMessage({'type': 'REQUEST_PENDING_FILES'});
  }

  /// Confirm a large file is fully downloaded AND stored, releasing the relay's
  /// copy. Only ever sent after the message is persisted — see the NEW_MESSAGE
  /// note above for why acking any earlier loses files.
  void confirmFileReceived(String messageId) {
    sendWSMessage({'type': 'FILE_RECEIVED', 'message_id': messageId});
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

  /// Server-side group fan-out: upload ONE envelope + the recipient list, and the
  /// relay routes that identical envelope to each recipient. Group envelopes are
  /// byte-identical (shared keystream, no per-recipient re-encryption), so a
  /// single copy — not a per-recipient map — is what saves the bandwidth. Only
  /// call when [supportsGroupFanout] is true; otherwise use the per-member loop.
  void sendBroadcastGroupMessage(
    List<String> recipientIds,
    String envelope,
    String contentType,
  ) {
    sendWSMessage({
      'type': 'BROADCAST_GROUP_MESSAGE',
      'recipients': recipientIds,
      'envelope': envelope,
      'content_type': contentType,
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
          final caps = jsonMap['capabilities'];
          _supportsGroupFanout =
              caps is List && caps.contains('group_fanout');
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
          // Reconcile large-file offers: recover any FILE_OFFER we missed while
          // previously connected (see requestPendingFiles). Idempotent.
          requestPendingFiles();
          break;
        case 'NEW_MESSAGE':
          final senderId = jsonMap['sender_id'] as String;
          final envelope = jsonMap['envelope'] as String;
          final contentType = jsonMap['content_type'] ?? 'text';
          final messageId = jsonMap['message_id'] as String?;

          _log('[WebSocket] Received NEW_MESSAGE from $senderId');
          if (onMessageReceived != null) {
            onMessageReceived!(senderId, envelope, contentType);
          }
          // Legacy inline delivery of a bucket-backed message (the relay falls
          // back to this when it can't build an offer). The ACK is deliberately
          // NOT sent here: acknowledging at the transport layer — before the
          // message is decrypted and written to the DB — told the relay to delete
          // the only copy, so anything that killed the app mid-store lost the
          // file for good. AppState acks once the message is safely persisted.
          if (messageId != null) {
            _log('[WebSocket] Inline file $messageId — ack deferred to storage');
          }
          break;
        case 'FILE_OFFER':
          // A large payload is waiting in the relay's bucket. We only get its
          // routing metadata now; the body is fetched on demand.
          final senderId = jsonMap['sender_id'] as String? ?? '';
          final contentType = jsonMap['content_type'] as String? ?? 'text';
          final messageId = jsonMap['message_id'] as String? ?? '';
          final meta = jsonMap['meta'] as String? ?? '';
          final size = (jsonMap['size'] as num?)?.toInt() ?? 0;
          _log(
            '[WebSocket] Received FILE_OFFER $messageId from $senderId ($size B)',
          );
          if (messageId.isNotEmpty) {
            onFileOffer?.call(senderId, contentType, messageId, meta, size);
          }
          break;
        case 'FILE_TOKEN':
          onFileToken?.call(
            jsonMap['message_id'] as String? ?? '',
            jsonMap['token'] as String?,
            null,
          );
          break;
        case 'FILE_ERROR':
          final messageId = jsonMap['message_id'] as String? ?? '';
          final message = jsonMap['message'] as String? ?? 'File unavailable';
          _log('[WebSocket] FILE_ERROR for $messageId: $message');
          onFileToken?.call(messageId, null, message);
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
