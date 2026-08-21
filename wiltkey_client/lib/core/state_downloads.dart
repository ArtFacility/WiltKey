part of 'state.dart';

/// Live progress of one in-flight download: bytes received out of the advertised
/// total (0 total = unknown length, show an indeterminate spinner).
class DownloadProgress {
  final int received;
  final int total;
  final String? error;
  const DownloadProgress(this.received, this.total, {this.error});

  double? get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : null;
  bool get failed => error != null;
}

/// On-demand large-file downloads.
///
/// Payloads at/above the relay's bucket threshold are no longer pushed down the
/// socket. The relay stores the body, sends us a `FILE_OFFER` carrying only the
/// envelope's routing metadata, and **keeps the body until we confirm we stored
/// it** (or its hold TTL expires). So:
///
///   * a half-finished or interrupted download costs nothing — retry it;
///   * the app being killed mid-decrypt can't destroy the only copy (the old
///     transport-level ACK did exactly that);
///   * an un-downloaded offer is re-advertised on every reconnect, which doubles
///     as the retry mechanism.
///
/// The placeholder message is stored immediately so the bubble (and its unread
/// badge) survives a restart even before the body is fetched.
extension AppStateDownloads on AppState {
  /// Relay-issued token waiters, keyed by relay message id.
  static final Map<String, Completer<String>> _tokenWaiters = {};

  void _setupDownloadCallbacks() {
    final ws = WebSocketClient();
    ws.onFileOffer = _handleFileOffer;
    ws.onFileToken = (messageId, token, error) {
      final waiter = _tokenWaiters.remove(messageId);
      if (waiter == null || waiter.isCompleted) return;
      if (token != null && token.isNotEmpty) {
        waiter.complete(token);
      } else {
        waiter.completeError(error ?? 'File unavailable');
      }
    };
  }

  /// A large payload is waiting on the relay. Store a placeholder message so the
  /// chat shows a download bubble right away; the body is fetched on tap.
  ///
  /// Runs through the same serialized inbound queue as live frames so it can't
  /// interleave with a resync writing the same chat.
  void _handleFileOffer(
    String senderId,
    String contentType,
    String messageId,
    String meta,
    int size,
  ) {
    final prev = _incomingLock;
    final completer = Completer<void>();
    _incomingLock = completer.future;
    prev.whenComplete(() async {
      try {
        await _storeFileOffer(senderId, contentType, messageId, meta, size);
      } catch (e) {
        log('[Download Error] Could not store file offer $messageId: $e');
      } finally {
        completer.complete();
      }
    });
  }

  Future<void> _storeFileOffer(
    String senderId,
    String contentType,
    String messageId,
    String meta,
    int size,
  ) async {
    // Hard block: drop file offers from blocked peers immediately.
    if (await WiltkeyDatabase.instance.isContactBlocked(senderId)) {
      log('[Download] Dropping FILE_OFFER from blocked peer $senderId');
      return;
    }

    Map<String, dynamic> env;
    try {
      env = jsonDecode(meta) as Map<String, dynamic>;
    } catch (_) {
      log('[Download] Ignoring FILE_OFFER $messageId with unreadable metadata.');
      return;
    }

    // Resolve the chat: group envelopes carry group_id, 1-on-1 ones are keyed by
    // the sender's key hash (exactly like _dispatchIncoming).
    final String? groupId = env['group_id'] as String?;
    final int idx = groupId != null
        ? contacts.indexWhere((c) => c.isGroup && c.keyHash == groupId)
        : contacts.indexWhere((c) => c.keyHash == senderId);
    if (idx == -1) {
      log('[Download] FILE_OFFER $messageId for unknown chat. Ignoring.');
      return;
    }
    final contact = contacts[idx];

    final String msgId = env['id'] as String? ?? messageId;
    // The relay re-offers everything we haven't ACKed on each reconnect, so the
    // same file legitimately arrives many times — only the first becomes a row.
    if (await WiltkeyDatabase.instance.messageExists(contact.id, id: msgId)) {
      return;
    }

    final String innerSender =
        (env['sender_id'] as String?) ?? (groupId != null ? senderId : contact.id);
    final int tsMillis = env['ts'] as int? ?? 0;

    final placeholder = ChatMessage(
      id: msgId,
      senderId: groupId != null ? innerSender : contact.id,
      text: '', // no ciphertext yet — it's still on the relay
      contentType: env['t'] as String? ?? contentType,
      timestamp: tsMillis > 0
          ? DateTime.fromMillisecondsSinceEpoch(tsMillis)
          : DateTime.now(),
      isSentByMe: false,
      offset: env['offset'] as int? ?? 0,
      allowSave: env['dl'] == true,
      ephemeral: env['eph'] == 1,
      ttlSeconds: env['ttl'] as int? ?? 0,
      remoteFileId: messageId,
      remoteSize: size,
    );

    appendLoadedMessage(contact.id, placeholder);
    bumpUnread(contact, placeholder);
    if (_isNotifiableMessage(placeholder)) emitMessageAlert(contact);
    await WiltkeyDatabase.instance.saveMessage(
      placeholder,
      contact.id,
      masterKeyHex: masterKeyHex,
    );
    notifyMessageReceived();
    log(
      '[Download] Pending ${AppState.formatBytes(size)} '
      '${placeholder.contentType} from ${contact.name} (relay id $messageId).',
    );
  }

  /// Fetch, decrypt and store a pending large file, then release the relay's
  /// copy. Safe to call repeatedly: a second call while one is in flight is a
  /// no-op, and a failure leaves the placeholder intact so it can be retried.
  Future<void> downloadPendingFile(Contact contact, ChatMessage msg) async {
    final String? fileId = msg.remoteFileId;
    if (fileId == null || fileId.isEmpty) return;
    if (downloadProgress.containsKey(msg.id)) return; // already running

    if (!WebSocketClient().isConnected) {
      _setDownloadProgress(msg.id, const DownloadProgress(0, 0, error: 'offline'));
      return;
    }

    _setDownloadProgress(msg.id, DownloadProgress(0, msg.remoteSize));
    try {
      final token = await _requestDownloadToken(fileId);
      final envelope = await _fetchFileBody(fileId, token, msg);

      // Drop the placeholder first: the group inbound path dedups by message id
      // and would treat our own placeholder as "already have it", so the real
      // body would never be stored. Safe to remove even if the next step throws —
      // the relay still holds the file (we haven't ACKed), so the offer simply
      // comes back on the next reconnect and rebuilds the placeholder.
      await WiltkeyDatabase.instance.deleteMessage(msg.id);
      // Also evict it from the in-memory window NOW, not just the DB. Otherwise
      // the stale placeholder (its remoteFileId about to be cleared, its text
      // empty) lingers alongside the real message _dispatchIncoming is about to
      // append — rendering as a spurious "[LOCKED: 0x]" spinner + empty bubble
      // until the page re-fetch below replaces the list.
      messages[contact.id]?.removeWhere((m) => m.id == msg.id);

      // Hand the body to the ordinary inbound path: it decrypts at the envelope
      // offset, advances the lane/offset bookkeeping, stores the real message and
      // fires the delivery receipt — exactly as if it had arrived inline.
      await _dispatchIncoming(
        contact.isGroup ? msg.senderId : contact.keyHash,
        envelope,
        msg.contentType,
      );

      // Only now is the file genuinely ours — let the relay drop its copy.
      final stored = await WiltkeyDatabase.instance.messageExists(
        contact.id,
        id: msg.id,
      );
      if (stored) {
        await WiltkeyDatabase.instance.clearPendingDownload(msg.id);
        msg.remoteFileId = null;
        WebSocketClient().confirmFileReceived(fileId);
        log('[Download] Stored $fileId and released the relay copy.');
      }
      downloadProgress.remove(msg.id);
      // Refresh the window so the freshly stored body replaces the placeholder.
      // Fetch FIRST, then swap in atomically — clearing messages[id] before the
      // async DB read left the chat momentarily empty (a visible flash on slower
      // reads). The placeholder row was already deleted, so this page has the
      // real message and no stale placeholder.
      if (loadedChats.contains(contact.id)) {
        final page = await WiltkeyDatabase.instance.getMessagesPage(
          contact.id,
          limit: AppState.messagePageSize,
          masterKeyHex: masterKeyHex,
        );
        messages[contact.id] = page;
        hasMoreOlder[contact.id] = page.length >= AppState.messagePageSize;
      }
      notifyMessageReceived();
    } catch (e) {
      log('[Download Error] $fileId failed: $e');
      _setDownloadProgress(
        msg.id,
        DownloadProgress(0, msg.remoteSize, error: '$e'),
      );
    }
  }

  void _setDownloadProgress(String messageId, DownloadProgress p) {
    downloadProgress[messageId] = p;
    downloadRevision.value++;
  }

  /// Clear a failed download so the bubble goes back to "tap to download".
  void clearDownloadError(String messageId) {
    final p = downloadProgress[messageId];
    if (p != null && p.failed) {
      downloadProgress.remove(messageId);
      downloadRevision.value++;
    }
  }

  Future<String> _requestDownloadToken(String fileId) async {
    final completer = Completer<String>();
    _tokenWaiters[fileId] = completer;
    WebSocketClient().requestFile(fileId);
    try {
      return await completer.future.timeout(const Duration(seconds: 20));
    } finally {
      _tokenWaiters.remove(fileId);
    }
  }

  /// Streams the body over HTTP, reporting progress as it lands. The relay keeps
  /// the object until we ACK, so an exception here is always safely retryable.
  Future<String> _fetchFileBody(
    String fileId,
    String token,
    ChatMessage msg,
  ) async {
    final base = WebSocketClient().activeRelayUrl;
    if (base == null || base.isEmpty) throw 'no relay connection';
    final uri = Uri.parse(
      '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}'
      '/api/v1/file?token=$token',
    );

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw 'relay returned ${response.statusCode}';
      }
      final int total = response.contentLength > 0
          ? response.contentLength
          : msg.remoteSize;

      final buffer = BytesBuilder(copy: false);
      await for (final chunk in response) {
        buffer.add(chunk);
        _setDownloadProgress(msg.id, DownloadProgress(buffer.length, total));
      }
      return utf8.decode(buffer.takeBytes());
    } finally {
      client.close(force: true);
    }
  }

  /// Re-offer sweep: nothing to do proactively — the relay re-advertises every
  /// un-ACKed file when we reconnect, which recreates any placeholder we lost.
  /// Exposed so callers can surface how many bodies are still on the relay.
  Future<int> pendingDownloadCount() =>
      WiltkeyDatabase.instance.countPendingDownloads();
}
