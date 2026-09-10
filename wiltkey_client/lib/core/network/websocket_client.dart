import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'pow_solver.dart';

/// Lifecycle of the connection/auth dance. Surfaced so the UI can explain
/// what a slow connect is doing (one-time token issuance can take seconds).
enum WsPhase {
  /// No connection attempt in flight.
  idle,

  /// Dialling the relay (TCP/TLS + WS handshake pending).
  connecting,

  /// Socket open, waiting for the relay's challenge / presenting our token.
  authenticating,

  /// Token-less connect: solving the PoW issuance challenge (slow path).
  issuing,

  /// PoW accepted — the relay demands the human-verification puzzle
  /// (Phase 2). The UI swaps the securing screen's progress column for the
  /// puzzle and submits the answer via [submitPuzzleAnswer].
  humanVerification,

  /// Authenticated — the socket is usable.
  connected,
}

class WebSocketClient {
  static final WebSocketClient _instance = WebSocketClient._internal();
  factory WebSocketClient() => _instance;

  WebSocketClient._internal();

  WebSocket? _socket;
  bool _isAuthenticated = false;
  // Whether the relay we're CURRENTLY connected to advertised group fan-out
  // (server-side broadcast). Per-connection: reset on every disconnect and set
  // from AUTH_OK, so switching to an older self-hosted relay falls back to the
  bool _supportsGroupFanout = false;
  bool get supportsGroupFanout => _isAuthenticated && _supportsGroupFanout;
  bool _supportsSocialStories = false;
  bool get supportsSocialStories => _isAuthenticated && _supportsSocialStories;
  // Relay advertised the full story frame set (fetch/react/reactions/delete) —
  // the HTTP story endpoints no longer exist, so these operations are WS-only.
  bool _supportsStoriesWS = false;
  bool get supportsStoriesWS => _isAuthenticated && _supportsStoriesWS;
  // Connected relay runs WK_TEST_MODE=true (an isolated test instance) — the
  // shell shows an unmistakable "TEST SERVER" banner so test data never ends
  // up mistaken for production.
  bool _isTestRelay = false;
  bool get isTestRelay => _isAuthenticated && _isTestRelay;
  Completer<Map<String, dynamic>>? _pendingStoryCompleter;
  Completer<List<dynamic>>? _pendingFeedCompleter;
  Completer<void>? _pendingReactCompleter;
  Completer<List<dynamic>>? _pendingReactionsCompleter;
  Completer<void>? _pendingDeleteCompleter;
  bool _isConnecting = false;
  // Socket open but the auth dance (CHALLENGE → AUTH → AUTH_OK, possibly with
  // a PoW issuance detour) has not concluded yet. While this is true, NO other
  // code path may dial: a second socket would bump the generation, kill the
  // in-flight dance mid-PoW, and inject a solved nonce into a socket that never
  // asked for it ("Expected AUTH_TOKEN_ISSUE frame"). Single-flight, end to end.
  bool _isAuthenticating = false;
  Timer? _authDeadline;
  String? _currentUrl; // the URL we're actively trying right now
  String? _primaryUrl; // the user's configured relay (rotation anchor)
  String? _publicKeyHex;
  Timer? _reconnectTimer;
  int _connectionGeneration =
      0; // Tracks connection lifecycle to ignore stale events

  /// Current lifecycle phase of the connection (for UI surfaces like the
  /// onboarding "Securing your connection" step and the re-auth banner).
  WsPhase _phase = WsPhase.idle;
  WsPhase get phase => _phase;
  void Function(WsPhase phase)? onPhaseChanged;
  void _setPhase(WsPhase p) {
    if (_phase == p) return;
    _phase = p;
    onPhaseChanged?.call(p);
  }

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

  /// True while a connect/auth dance is in flight (dial → AUTH_OK). Watchdogs
  /// and self-heal must treat this as "the socket is being tended to" and NOT
  /// force a reconnect — that's what kills in-flight issuance.
  bool get isBusy => _isConnecting || _isAuthenticating;

  // Stream controller to broadcast connection status updates
  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  // Injection Callbacks
  void Function(String message)? onLog;
  void Function(bool connected)? onStatusChanged;
  FutureOr<String> Function(String challenge)? onSignChallenge;
  /// Loads the stored device token (raw). The token is the credential that
  /// lets a connect skip the relay's PoW issuance gate; it is challenge-bound
  /// at every auth (the signature covers challenge||token), so it stays a
  /// low-sensitivity bearer secret — useless without the private key.
  Future<String?> Function()? onGetDeviceToken;
  /// Persists a refreshed/issued device token (null = clear: the relay
  /// rejected ours, so the next connect goes through issuance instead).
  Future<void> Function(String? token)? onDeviceTokenUpdated;
  /// Live progress while solving the issuance PoW: (iterations so far, best
  /// leading zero-bits achieved, requested difficulty). Fires periodically from
  /// the solver isolate; used by the onboarding "Securing your connection" step.
  void Function(int iterations, int zeroBits, int difficulty)? onPoWProgress;
  /// The relay demands the human-verification puzzle (Phase 2): render it
  /// from (challengeId, seed, strips) and submit via [submitPuzzleAnswer].
  void Function(String challengeId, String seed, int strips)? onPuzzleChallenge;
  String? _activeChallengeId;
  String? _deviceToken;
  /// Hard backoff after an issuance rejection (rate-limited / bad PoW):
  /// connects are skipped until this lapses so we never burn battery
  /// re-solving a PoW the relay will refuse anyway.
  DateTime? _issuanceBackoffUntil;
  /// WHY the last issuance backoff was armed (challenge_cooldown,
  /// issuance_rate_limited, ...) — surfaced in the connection-issue dialog so
  /// users can tell "relay is down" from "this network tripped spam
  /// protection". Null when the last dance failed for other reasons.
  String? _issuanceBackoffReason;
  String? get issuanceBackoffReason => _issuanceBackoffReason;
  bool get isIssuanceBackoffActive {
    final b = _issuanceBackoffUntil;
    return b != null && DateTime.now().isBefore(b);
  }
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
    final urlChanged = _primaryUrl != httpUrl;
    _primaryUrl = httpUrl;
    // Single-flight: a dance already in progress owns the socket. Resetting
    // rotation/counters (or dialling a second socket) here would sabotage it.
    if (isBusy) {
      _log('[WebSocket] connect() ignored — dial/auth already in flight.');
      return;
    }
    // Already authenticated to THIS relay? A second dial would tear down a
    // working socket for nothing (and the old connection's server-side
    // unregister can then race the new one). Relay changes still re-dial.
    if (isConnected && !urlChanged) {
      _log('[WebSocket] connect() ignored — already connected.');
      return;
    }
    _rotationIndex = 0;
    _failCount = 0;
    _attemptConnect(httpUrl);
  }

  void _attemptConnect(String httpUrl) {
    if (isBusy) {
      _log('[WebSocket] Connect suppressed — dial/auth already in flight.');
      return;
    }
    // Respect the issuance backoff — the relay refused our last attempt and
    // will keep refusing until the window lapses.
    final backoff = _issuanceBackoffUntil;
    if (backoff != null && DateTime.now().isBefore(backoff)) {
      final remaining = backoff.difference(DateTime.now());
      _log('[WebSocket] Connect deferred — issuance backoff active (${remaining.inMinutes} min left)');
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(remaining, () {
        _issuanceBackoffUntil = null;
        _attemptConnect(httpUrl);
      });
      return;
    }
    _currentUrl = httpUrl;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectionGeneration++; // Invalidate all callbacks from previous connections
    final gen = _connectionGeneration;
    _closeSocket();
    _setPhase(WsPhase.connecting);

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
          _isAuthenticating = true;
          _setPhase(WsPhase.authenticating);
          _log('[WebSocket] Connected. Waiting for challenge...');
          // Handshake deadline: if the relay never completes the auth dance
          // (dead relay behind a live LB, black-holed socket), single-flight
          // would otherwise block every future reconnect forever. 60s covers
          // slow-device PoW solving with headroom.
          _authDeadline?.cancel();
          _authDeadline = Timer(const Duration(seconds: 60), () {
            if (gen != _connectionGeneration) return;
            _log('[WebSocket] Auth deadline exceeded — tearing down.');
            _handleDisconnect();
          });

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
      _supportsSocialStories = false;
      _supportsStoriesWS = false;
      _isTestRelay = false;
      _statusController.add(false);
      onStatusChanged?.call(false);
    }
    void fail(Completer? c) {
      if (c != null && !c.isCompleted) c.completeError(Exception('WebSocket connection closed'));
    }
    fail(_pendingStoryCompleter);
    fail(_pendingFeedCompleter);
    fail(_pendingReactCompleter);
    fail(_pendingReactionsCompleter);
    fail(_pendingDeleteCompleter);
    _pendingStoryCompleter = null;
    _pendingFeedCompleter = null;
    _pendingReactCompleter = null;
    _pendingReactionsCompleter = null;
    _pendingDeleteCompleter = null;
    old?.close();
  }

  /// Set when the relay EXPLICITLY rejected us (AUTH_REJECTED): the relay
  /// closes the socket right after, and that teardown must not count toward
  /// relay-unreachable rotation. Consumed by the next [_handleDisconnect].
  bool _rejectionPending = false;

  void _handleDisconnect({bool serverRejected = false}) {
    serverRejected = serverRejected || _rejectionPending;
    _rejectionPending = false;
    _isConnecting = false;
    _isAuthenticating = false;
    _activeChallengeId = null;
    _authDeadline?.cancel();
    _authDeadline = null;
    _setPhase(WsPhase.idle);
    _closeSocket();
    // Server REJECTIONS mean the relay was reached and answered — they say
    // nothing about the relay being unreachable. Counting them as connection
    // failures rotated us onto OTHER relays mid-issuance, scattering
    // per-relay state (challenge strikes, tokens, queues) and even dropping
    // test-relay devices onto production. Only network failures rotate.
    if (!serverRejected) _failCount++;

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
    _reconnectTimer = null;
    _authDeadline?.cancel();
    _authDeadline = null;
    _activeChallengeId = null;
    _isConnecting = false;
    _isAuthenticating = false;
    _setPhase(WsPhase.idle);
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
    // Auth gate: while the handshake hasn't concluded, ONLY the auth-dance
    // frames may go out. Any other frame here is a caller that ignored
    // isBusy (e.g. a group-sync retry firing mid-issuance) — the relay
    // expects AUTH_TOKEN_ISSUE and closes on junk ("Expected
    // AUTH_TOKEN_ISSUE frame" from the field, 2026-09-08).
    const authFrames = {'AUTH', 'AUTH_TOKEN_ISSUE', 'AUTH_CHALLENGE_SOLUTION'};
    final type = msgMap['type'] as String? ?? '';
    if (!_isAuthenticated && !authFrames.contains(type)) {
      _log('[WebSocket] Dropped $type — connection not authenticated yet.');
      return;
    }
    if (_socket == null) {
      _log('[WebSocket] Cannot send message, socket is null');
      return;
    }
    _socket!.add(jsonEncode(msgMap));
  }

  /// Submits the human-verification puzzle answer for the active challenge
  /// (Phase 2). The UI calls this from the puzzle's Lock-in button.
  void submitPuzzleAnswer(int answer) {
    final id = _activeChallengeId;
    if (id == null) {
      _log('[WebSocket] submitPuzzleAnswer with no active challenge');
      return;
    }
    sendWSMessage({
      'type': 'AUTH_CHALLENGE_SOLUTION',
      'challenge_id': id,
      'answer': answer,
    });
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

  /// Publishes a 24-hour Wilting Story over the authenticated WebSocket.
  Future<Map<String, dynamic>> postStory({
    required String storyType,
    required String ciphertextB64,
    String? mediaMeta,
  }) async {
    if (!supportsStoriesWS) {
      throw Exception('Relay does not support WebSocket stories');
    }
    if (_pendingStoryCompleter != null && !_pendingStoryCompleter!.isCompleted) {
      _pendingStoryCompleter!.completeError(Exception('Cancelled by newer story publish'));
      _pendingStoryCompleter = null;
    }
    final completer = Completer<Map<String, dynamic>>();
    _pendingStoryCompleter = completer;

    sendWSMessage({
      'type': 'POST_STORY',
      'story_type': storyType,
      'ciphertext_b64': ciphertextB64,
      'media_meta': mediaMeta ?? '',
    });

    return completer.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        if (_pendingStoryCompleter == completer) {
          _pendingStoryCompleter = null;
        }
        throw TimeoutException('Timed out waiting for story confirmation from relay');
      },
    );
  }

  /// Fetches the stories feed (own + [contacts]' stories) over the WS.
  /// Requires the relay to advertise [supportsStoriesWS] — the HTTP feed
  /// endpoint no longer exists.
  ///
  /// While NOT authenticated (background refresh racing a disconnect), this
  /// returns [] quietly instead of erroring: the feed refreshes again when
  /// AUTH_OK lands. A CONNECTED relay lacking the capability still throws —
  /// that's a genuine old-relay mismatch worth surfacing.
  Future<List<dynamic>> fetchStories(List<String> contacts) async {
    if (!isConnected) {
      _log('[WebSocket] fetchStories skipped — not authenticated (offline?).');
      return [];
    }
    if (!supportsStoriesWS) {
      throw Exception('Relay does not support WebSocket stories');
    }
    if (_pendingFeedCompleter != null && !_pendingFeedCompleter!.isCompleted) {
      _pendingFeedCompleter!.completeError(Exception('Cancelled by newer feed fetch'));
      _pendingFeedCompleter = null;
    }
    final completer = Completer<List<dynamic>>();
    _pendingFeedCompleter = completer;

    sendWSMessage({'type': 'FETCH_STORIES', 'contacts': contacts});

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        if (_pendingFeedCompleter == completer) _pendingFeedCompleter = null;
        throw TimeoutException('Timed out waiting for stories feed from relay');
      },
    );
  }

  /// Records/updates our reaction emoji on [storyId] over the WS.
  Future<void> reactToStory(String storyId, String emoji) async {
    if (!supportsStoriesWS) {
      throw Exception('Relay does not support WebSocket stories');
    }
    if (_pendingReactCompleter != null && !_pendingReactCompleter!.isCompleted) {
      _pendingReactCompleter!.completeError(Exception('Cancelled by newer reaction'));
      _pendingReactCompleter = null;
    }
    final completer = Completer<void>();
    _pendingReactCompleter = completer;

    sendWSMessage({'type': 'STORY_REACT', 'story_id': storyId, 'emoji': emoji});

    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        if (_pendingReactCompleter == completer) _pendingReactCompleter = null;
        throw TimeoutException('Timed out waiting for reaction confirmation');
      },
    );
  }

  /// Fetches the reaction list of one of OUR stories (author-only server-side).
  Future<List<dynamic>> fetchStoryReactions(String storyId) async {
    if (!supportsStoriesWS) {
      throw Exception('Relay does not support WebSocket stories');
    }
    if (_pendingReactionsCompleter != null && !_pendingReactionsCompleter!.isCompleted) {
      _pendingReactionsCompleter!.completeError(Exception('Cancelled by newer reactions fetch'));
      _pendingReactionsCompleter = null;
    }
    final completer = Completer<List<dynamic>>();
    _pendingReactionsCompleter = completer;

    sendWSMessage({'type': 'FETCH_STORY_REACTIONS', 'story_id': storyId});

    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        if (_pendingReactionsCompleter == completer) _pendingReactionsCompleter = null;
        throw TimeoutException('Timed out waiting for story reactions');
      },
    );
  }

  /// Deletes one of our own stories over the WS.
  Future<void> deleteStory(String storyId) async {
    if (!supportsStoriesWS) {
      throw Exception('Relay does not support WebSocket stories');
    }
    if (_pendingDeleteCompleter != null && !_pendingDeleteCompleter!.isCompleted) {
      _pendingDeleteCompleter!.completeError(Exception('Cancelled by newer delete'));
      _pendingDeleteCompleter = null;
    }
    final completer = Completer<void>();
    _pendingDeleteCompleter = completer;

    sendWSMessage({'type': 'DELETE_STORY', 'story_id': storyId});

    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        if (_pendingDeleteCompleter == completer) _pendingDeleteCompleter = null;
        throw TimeoutException('Timed out waiting for story deletion');
      },
    );
  }

  Future<void> _handleIncomingData(dynamic data) async {
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
        case 'TOKEN_CHALLENGE':
          // Token-less connect: the relay wants proof-of-spend before minting
          // our device token. Solve the PoW (background isolate — one-time per
          // install) and submit it, bound to our pubkey via the payload.
          final challenge = jsonMap['challenge'] as String? ?? '';
          final difficulty = (jsonMap['difficulty'] as num?)?.toInt() ?? 5;
          if (_publicKeyHex == null || challenge.isEmpty) {
            _log('[WebSocket] TOKEN_CHALLENGE received but identity missing');
            break;
          }
          _setPhase(WsPhase.issuing);
          _log('[WebSocket] Solving issuance PoW (difficulty $difficulty)...');
          // The solve outlives the socket that asked for it (slow devices can
          // take 10s+). Bind the result to THIS generation: if the socket died
          // mid-solve, the nonce belongs to a dead challenge and must never be
          // injected into the replacement connection.
          final powGen = _connectionGeneration;
          try {
            final nonce = await solvePoW(
              challenge: challenge,
              payload: _publicKeyHex!,
              difficulty: difficulty,
              onProgress: (it, zb) => onPoWProgress?.call(it, zb, difficulty),
            );
            if (powGen != _connectionGeneration || _socket == null) {
              _log(
                '[WebSocket] PoW solved but its connection is gone (gen=$powGen, current=$_connectionGeneration) — discarding.',
              );
              break;
            }
            _log('[WebSocket] PoW solved (nonce $nonce) — requesting token');
            sendWSMessage({'type': 'AUTH_TOKEN_ISSUE', 'pow_nonce': nonce});
          } catch (e) {
            _log('[WebSocket] PoW solving failed: $e');
          }
          break;
        case 'AUTH_CHALLENGE_REQUIRED':
          // Phase 2: the PoW was accepted; the relay wants the human puzzle
          // solved before minting. The auth deadline still runs — the relay
          // enforces its own 90s solution window and closes on lapse, which
          // lands as a normal disconnect/reconnect.
          final challengeId = jsonMap['challenge_id'] as String? ?? '';
          final seed = jsonMap['seed'] as String? ?? '';
          final strips = (jsonMap['strips'] as num?)?.toInt() ?? 5;
          if (challengeId.isEmpty || seed.isEmpty) {
            _log('[WebSocket] AUTH_CHALLENGE_REQUIRED missing seed/id');
            break;
          }
          _log('[WebSocket] Human challenge required ($challengeId, $strips strips)');
          _activeChallengeId = challengeId;
          _setPhase(WsPhase.humanVerification);
          onPuzzleChallenge?.call(challengeId, seed, strips);
          break;
        case 'AUTH_REJECTED':
          final reason = jsonMap['message'] as String? ?? 'rejected';
          _log('[WebSocket] Auth rejected: $reason');
          // The relay always closes after a rejection; the resulting onDone
          // must not count as a relay-unreachable failure (see
          // _handleDisconnect). Consumed by the next disconnect.
          _rejectionPending = true;
          if (reason == 'token_invalid') {
            // Our stored token is unknown/expired/revoked — drop it so the
            // next connect goes through the issuance gate, then reconnect.
            _deviceToken = null;
            await onDeviceTokenUpdated?.call(null);
            _handleDisconnect(serverRejected: true);
          } else if (reason == 'challenge_failed') {
            // Wrong puzzle answer — the dance is dead; a fresh reconnect
            // presents a NEW puzzle. Strikes/cooldown are the relay's job;
            // the client just restarts cleanly.
            _handleDisconnect(serverRejected: true);
          } else if (reason == 'challenge_cooldown' ||
              reason == 'challenge_unavailable') {
            // Cooldown armed from earlier wrong answers — back off instead
            // of tight-looping reconnects into a guaranteed rejection.
            _issuanceBackoffReason = 'challenge_cooldown';
            _issuanceBackoffUntil =
                DateTime.now().add(const Duration(minutes: 2));
            _log('[WebSocket] Challenge cooldown — backing off until $_issuanceBackoffUntil');
          } else if (reason == 'challenge_upgrade_required') {
            // The relay runs the challenge mode but this app build predates
            // the puzzle — the website force-update path takes over from
            // here; back off instead of hammering a guaranteed rejection.
            _issuanceBackoffReason = 'challenge_upgrade_required';
            _issuanceBackoffUntil =
                DateTime.now().add(const Duration(minutes: 30));
            _log('[WebSocket] Challenge upgrade required — update the app (backing off)');
          } else if (reason == 'issuance_rate_limited') {
            // The whole NAT IP is capped until day-rollover. Re-solving the
            // PoW every 5s would drain battery and hammer the relay for a
            // guaranteed rejection — back off HARD (the watchdog still
            // reconnects once the backoff lapses).
            _issuanceBackoffReason = 'issuance_rate_limited';
            _issuanceBackoffUntil = DateTime.now().add(const Duration(hours: 1));
            _log('[WebSocket] Issuance rate-limited — backing off until $_issuanceBackoffUntil');
          } else if (reason == 'pow_invalid') {
            // Our solver/protocol disagrees with the relay — retry later, not
            // in a tight loop.
            _issuanceBackoffReason = 'pow_invalid';
            _issuanceBackoffUntil = DateTime.now().add(const Duration(minutes: 5));
          }
          break;
        case 'AUTH_OK':
          // A successful dance retires any armed issuance backoff — the gate
          // is behind us and future reconnects must not be deferred.
          _issuanceBackoffUntil = null;
          _issuanceBackoffReason = null;
          _isAuthenticated = true;
          // A refreshed/issued device token rides AUTH_OK — persist it before
          // anything else so a crash right after connect can't lose it.
          final freshToken = jsonMap['device_token'] as String?;
          if (freshToken != null && freshToken.isNotEmpty) {
            _deviceToken = freshToken;
            await onDeviceTokenUpdated?.call(freshToken);
          }
          final caps = jsonMap['capabilities'];
          _supportsGroupFanout =
              caps is List && caps.contains('group_fanout');
          _supportsSocialStories =
              caps is List && caps.contains('social_stories');
          _supportsStoriesWS = caps is List && caps.contains('stories_ws');
          _isTestRelay = caps is List && caps.contains('test_mode');
          // A live connection clears the failure streak and pins rotation to the
          // relay that actually worked, so we stay put instead of drifting off it.
          _failCount = 0;
          final workingIdx = _candidates.indexOf(_currentUrl ?? '');
          if (workingIdx >= 0) _rotationIndex = workingIdx;
          _statusController.add(true);
          onStatusChanged?.call(true);
          final serverUserId = jsonMap['user_id'] as String;
          _isAuthenticating = false;
          _authDeadline?.cancel();
          _authDeadline = null;
          _activeChallengeId = null;
          _setPhase(WsPhase.connected);
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
        case 'POST_STORY_OK':
          _log('[WebSocket] Received POST_STORY_OK, storyId: ${jsonMap['story_id']}');
          _pendingStoryCompleter?.complete(jsonMap);
          _pendingStoryCompleter = null;
          break;
        case 'POST_STORY_ERROR':
          final errorMsg = jsonMap['message'] as String? ?? 'Failed to publish story';
          _log('[WebSocket] Received POST_STORY_ERROR: $errorMsg');
          _pendingStoryCompleter?.completeError(Exception(errorMsg));
          _pendingStoryCompleter = null;
          break;
        case 'STORIES_FEED':
          final stories = jsonMap['stories'] as List? ?? [];
          _pendingFeedCompleter?.complete(stories);
          _pendingFeedCompleter = null;
          break;
        case 'STORIES_ERROR':
          _pendingFeedCompleter?.completeError(
            Exception(jsonMap['message'] as String? ?? 'Failed to fetch stories feed'),
          );
          _pendingFeedCompleter = null;
          break;
        case 'STORY_REACT_OK':
          _pendingReactCompleter?.complete(null);
          _pendingReactCompleter = null;
          break;
        case 'STORY_REACT_ERROR':
          _pendingReactCompleter?.completeError(
            Exception(jsonMap['message'] as String? ?? 'Failed to record reaction'),
          );
          _pendingReactCompleter = null;
          break;
        case 'STORY_REACTIONS':
          _pendingReactionsCompleter?.complete(jsonMap['reactions'] as List? ?? []);
          _pendingReactionsCompleter = null;
          break;
        case 'STORY_REACTIONS_ERROR':
          _pendingReactionsCompleter?.completeError(
            Exception(jsonMap['message'] as String? ?? 'Failed to fetch story reactions'),
          );
          _pendingReactionsCompleter = null;
          break;
        case 'DELETE_STORY_OK':
          _pendingDeleteCompleter?.complete(null);
          _pendingDeleteCompleter = null;
          break;
        case 'DELETE_STORY_ERROR':
          _pendingDeleteCompleter?.completeError(
            Exception(jsonMap['message'] as String? ?? 'Failed to delete story'),
          );
          _pendingDeleteCompleter = null;
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
    // Signing crosses an async platform channel; the socket can die under us.
    // Only answer on the connection that asked.
    final gen = _connectionGeneration;

    // Present our device token when we hold one: the signature then covers
    // challenge||token, binding token possession to the private key on THIS
    // connection. Without a token we sign the bare challenge and the relay
    // answers with a PoW issuance challenge instead of AUTH_OK.
    String? token = _deviceToken;
    if (token == null || token.isEmpty) {
      token = await onGetDeviceToken?.call();
      _deviceToken = (token != null && token.isNotEmpty) ? token : null;
    }
    final hasToken = _deviceToken != null && _deviceToken!.isNotEmpty;
    final payload = hasToken ? '$challenge$_deviceToken' : challenge;

    _log('[WebSocket] Responding to CHALLENGE (${hasToken ? "with device token" : "tokenless — issuance expected"})...');
    final signatureHex = await onSignChallenge!(payload);
    if (gen != _connectionGeneration || _socket == null) {
      _log('[WebSocket] Challenge response discarded — connection replaced.');
      return;
    }

    sendWSMessage({
      'type': 'AUTH',
      'pubkey': _publicKeyHex,
      'signature': signatureHex,
      if (hasToken) 'device_token': _deviceToken,
      // Negotiation: only clients advertising the human-verification cap can
      // be served the Phase-2 puzzle; the relay flips per-capability so app
      // and relay rollouts stay independent.
      'client_caps': ['human_challenge'],
    });
  }

  String _getWsUrl(String httpUrl) {
    final uri = Uri.parse(httpUrl);
    final scheme = (uri.scheme == 'https') ? 'wss' : 'ws';
    final path = uri.path.endsWith('/') ? '${uri.path}ws' : '${uri.path}/ws';
    return uri.replace(scheme: scheme, path: path).toString();
  }
}
