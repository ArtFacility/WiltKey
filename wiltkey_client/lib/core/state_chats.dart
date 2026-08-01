part of 'state.dart';

extension AppStateChats on AppState {
  /// Marks a chat read up to now (clears its unread badge). Called when opening a
  /// chat and when leaving it, so messages seen during the session don't linger.
  void markChatRead(Contact contact) {
    lastReadMs[contact.id] = DateTime.now().millisecondsSinceEpoch;
    unreadCounts.remove(contact.id);
    _persistence.saveState(this);
    notifyListeners();
  }

  /// Unread badge count for a chat (DB-derived; kept live as messages arrive).
  int unreadCount(Contact contact) => unreadCounts[contact.id] ?? 0;

  /// Belt-and-suspenders for [visibleChatId]: call when a pushed chat route pops
  /// back to the dashboard, so that chat's unread badge + in-app banner resume
  /// immediately even if the chat screen's own `dispose` didn't clear the flag
  /// (lifecycle/timing edge cases). Safe no-op if a different chat is now on top.
  void clearVisibleChatIfCurrent(String chatId) {
    if (visibleChatId == chatId) {
      visibleChatId = null;
      notifyListeners();
    }
  }

  /// Bumps a chat's unread count for a freshly-arrived inbound message, unless
  /// that chat is the one currently open. Control writes / system lines never
  /// count. Call only for live arrivals (not historical resync replays).
  void bumpUnread(Contact contact, ChatMessage msg) {
    if (msg.isSentByMe || msg.isSystem) return;
    if (msg.contentType == 'emoji_def' || msg.contentType == 'emoji_delete')
      return;
    if (visibleChatId == contact.id) return; // user is actively viewing it
    unreadCounts[contact.id] = (unreadCounts[contact.id] ?? 0) + 1;
  }

  /// Loads a chat's most-recent page into the in-memory window (idempotent — a
  /// no-op once loaded). Called when a chat is opened.
  Future<void> loadInitialMessages(Contact contact) async {
    if (loadedChats.contains(contact.id)) return;
    final page = await WiltkeyDatabase.instance.getMessagesPage(
      contact.id,
      limit: AppState.messagePageSize,
      masterKeyHex: masterKeyHex,
    );
    messages[contact.id] = page;
    loadedChats.add(contact.id);
    hasMoreOlder[contact.id] = page.length >= AppState.messagePageSize;
    notifyListeners();
  }

  /// Prepends the next older page for a chat (scroll-back). Returns how many new
  /// messages were prepended (0 when nothing older remains).
  Future<int> loadOlderMessages(Contact contact) async {
    if (hasMoreOlder[contact.id] != true) return 0;
    final current = messages[contact.id] ?? [];
    if (current.isEmpty) return 0;
    final oldestIso = current.first.timestamp.toIso8601String();
    final older = await WiltkeyDatabase.instance.getMessagesPage(
      contact.id,
      limit: AppState.messagePageSize,
      beforeTimestamp: oldestIso,
      masterKeyHex: masterKeyHex,
    );
    if (older.isEmpty) {
      hasMoreOlder[contact.id] = false;
      return 0;
    }
    // Dedup against the boundary (messages sharing the cursor timestamp).
    final existingIds = {for (final m in current) m.id};
    final fresh = [
      for (final m in older)
        if (!existingIds.contains(m.id)) m,
    ];
    messages[contact.id] = [...fresh, ...current];
    hasMoreOlder[contact.id] = older.length >= AppState.messagePageSize;
    notifyListeners();
    return fresh.length;
  }

  void selectContact(Contact contact) {
    activeContact = contact;
    visibleChatId = contact.id; // the chat screen is about to be shown
    lastReadMs[contact.id] =
        DateTime.now().millisecondsSinceEpoch; // clear unread on open
    unreadCounts.remove(contact.id);
    // Opening a chat means the user has seen its alerts: drop any lingering tray
    // notification and dismiss the in-app banner if it's pointing here.
    WiltkeyNotifications.cancelMessageNotifications();
    if (messageAlert.value?.contact.id == contact.id) messageAlert.value = null;
    if (contact.isArchived) {
      // Read-only: no pad, no peer relationship to refresh or sync.
      notifyListeners();
      return;
    }
    if (contact.isGroup) {
      // Pulls fresh metadata (spokes) + sweeps missed messages from all members.
      // Emoji defs/deletes ride this same resync sweep — no separate channel.
      autoSyncGroup(contact);
    } else {
      // Push our current profile/permissions so the peer's view stays fresh.
      sendChatInfoUpdate(contact);
    }
    notifyListeners();
  }

  /// Returns null on success, or an error message string if sending fails.
  ///
  /// To keep the UI responsive, the bubble is shown immediately as a pending
  /// ("Encrypting…") placeholder BEFORE the slow work (socket self-heal +
  /// keystream XOR + DB writes). The keystream offset is reserved synchronously
  /// up front so rapid successive sends never collide, then the same message is
  /// finalized in place once the ciphertext is ready.
  Future<String?> sendMessage(
    String text, {
    String contentType = 'text',
    String? mimeType,
    bool allowSave = false,
    bool ephemeral = false,
    int ttlSeconds = 0,
    String? replyToId,
  }) async {
    log('sendMessage starting. type: $contentType, len: ${text.length}');
    if (activeContact == null || status == AppStatus.nuked) {
      log('sendMessage error: contact is null or app nuked');
      return 'App is nuked';
    }
    final contact = activeContact!;
    log('Sending to contact: ${contact.name} (${contact.keyHash})');
    log(
      'Outgoing offset: ${contact.outgoingOffset}, max: ${contact.outgoingMaxOffset}, remaining: ${contact.remainingBufferBytes}',
    );

    if (contact.remainingBufferBytes < 74) {
      // Empty lane: try to borrow keystream from the peer (1-on-1 only) so the
      // chat can recover instead of dead-ending.
      if (!contact.isGroup) requestBorrow(contact);
      log('sendMessage error: charge < 74 (requested borrow)');
      return 'Out of keystream — asked your peer for more bytes. Try again in a moment.';
    }

    // A reply embeds the parent id in the OTP body (hidden from the blind relay),
    // so it costs a few extra pad bytes vs a plain message. Non-replies are
    // unchanged. The in-memory/DB copies keep the original text + replyToId; only
    // the encrypted wire body carries the framed form.
    final String wireText = ChatMessage.buildReplyBody(replyToId, text);
    final payloadBytes = utf8.encode(wireText).length;

    // Pick where to encrypt: our primary sending lane first, otherwise a
    // disjoint range the peer donated to us (borrowed keystream). If nothing
    // fits anywhere, ask the peer to donate more and bail out for now.
    final int? currentOffset = _pickSendOffset(contact, payloadBytes);
    if (currentOffset == null) {
      log(
        'sendMessage: out of keystream (primary + borrowed). Requesting a borrow.',
      );
      requestBorrow(contact);
      return 'Out of keystream in your lane — asked your peer for more bytes. Try again in a moment.';
    }

    // Reserve the offset NOW (synchronously) so a second send during our awaits
    // picks the next range, then recompute remaining capacity across all ranges.
    _advanceSendPointer(contact, currentOffset, payloadBytes);
    contact.remainingBufferBytes = _sendCapacity(contact);
    contact.isWilted = contact.remainingBufferBytes < 74;

    // Show the bubble immediately as a pending placeholder (no DB write yet).
    final newMessage = ChatMessage(
      id: DateTime.now().toString(),
      senderId: 'me',
      text: '', // ciphertext filled in on finalize
      contentType: contentType,
      timestamp: DateTime.now(),
      isSentByMe: true,
      offset: currentOffset,
      isPending: true,
      decodedImageBytes:
          (contentType == 'image' || contentType == 'image_hidden')
          ? base64Decode(text)
          : null,
      allowSave: allowSave,
      decodedAudioBytes: contentType == 'voice' ? base64Decode(text) : null,
      decryptedText: text, // original plaintext cached in-memory
      ephemeral: ephemeral,
      ttlSeconds: ephemeral ? ttlSeconds : 0,
      replyToId: replyToId,
    );
    appendLoadedMessage(contact.id, newMessage);
    notifyListeners();

    // Self-heal the socket, then encrypt — the slow steps the placeholder hides.
    await ensureWebSocketConnected();

    List<int> cipherBytes;
    try {
      final rawBytes = utf8.encode(wireText);
      cipherBytes = await WiltkeyOtpService.xorWithKeystream(
        contact.keyHash,
        rawBytes,
        currentOffset,
      );
      log(
        'Encryption success. Plain bytes: ${rawBytes.length}, offset: $currentOffset',
      );
    } catch (e) {
      log('Encryption error: $e');
      // Undo the placeholder + offset reservation so nothing leaks on failure.
      messages[contact.id]?.removeWhere((m) => m.id == newMessage.id);
      _rollbackSendPointer(contact, currentOffset, payloadBytes);
      contact.remainingBufferBytes = _sendCapacity(contact);
      contact.isWilted = contact.remainingBufferBytes < 74;
      notifyListeners();
      return 'Encryption failed: $e';
    }
    final base64Cipher = base64Encode(cipherBytes);

    final bool socketConnected = WebSocketClient().isConnected;
    log('Socket state: isConnected=$socketConnected');

    // Finalize the same message object in place.
    newMessage.text = base64Cipher; // ciphertext
    newMessage.isPending = false;
    newMessage.isFailed = !socketConnected;

    await WiltkeyDatabase.instance.saveMessage(
      newMessage,
      contact.id,
      masterKeyHex: masterKeyHex,
    );
    await WiltkeyDatabase.instance.upsertContact(contact);
    notifyListeners();
    _persistence.saveState(this);

    // Proactively top up while there's still a little room left.
    if (contact.remainingBufferBytes < 500) {
      requestBorrow(contact);
    }

    if (socketConnected) {
      // Build structured envelope containing ciphertext and offset
      final Map<String, dynamic> envelope = {
        't': contentType,
        'd': base64Cipher,
        'offset': currentOffset,
        'id': newMessage.id,
      };
      if (mimeType != null) envelope['mime'] = mimeType;
      if (allowSave) envelope['dl'] = true;
      if (ephemeral) {
        envelope['eph'] = 1;
        envelope['ttl'] = ttlSeconds;
      }
      // NOTE: reply target is NOT here — it's embedded in the encrypted body
      // (wireText) so the relay never sees the reply relationship.
      final envelopeStr = jsonEncode(envelope);

      // Send payload over WebSocket
      WebSocketClient().sendWSMessage({
        'type': 'SEND_MESSAGE',
        'recipient_id': contact.keyHash,
        'envelope': envelopeStr,
        'content_type': contentType,
      });
    }

    return null; // success
  }

  Future<void> clearFailedMessage(Contact contact, ChatMessage message) async {
    final list = messages[contact.id] ?? [];
    final updatedList = list.where((m) => m.id != message.id).toList();
    messages[contact.id] = updatedList;

    // Calculate length of plaintext
    final int payloadBytes = message.decryptedText != null
        ? utf8.encode(message.decryptedText!).length
        : 0;

    // Refund: for 1-on-1, roll back whichever pointer this message advanced
    // (primary lane OR a borrowed range) so the keystream can be reused instead
    // of leaving a hole, then recompute capacity across all ranges. Groups keep
    // the simple charge refund.
    if (!contact.isGroup) {
      if (payloadBytes > 0) {
        if (message.offset + payloadBytes == contact.outgoingOffset) {
          contact.outgoingOffset = message.offset;
          log(
            '[Clear Message] Rolled back outgoingOffset to ${message.offset}',
          );
        } else {
          final a = contact.additionalSlots;
          for (int i = 0; i + 2 < a.length; i += 3) {
            if (a[i + 1] == message.offset + payloadBytes) {
              a[i + 1] = message.offset;
              log(
                '[Clear Message] Rolled back borrowed-range pointer to ${message.offset}',
              );
              break;
            }
          }
        }
      }
      contact.remainingBufferBytes = _sendCapacity(contact);
    } else {
      final byteCost = payloadBytes + 73;
      contact.remainingBufferBytes = min(
        contact.maxBufferBytes,
        contact.remainingBufferBytes + byteCost,
      );
    }
    if (contact.remainingBufferBytes >= 74) {
      contact.isWilted = false;
    }

    await WiltkeyDatabase.instance.deleteMessage(message.id);
    await WiltkeyDatabase.instance.upsertContact(contact);

    notifyListeners();
    _persistence.saveState(this);
  }

  /// Launch-time sweep: any message left in a failed state from a previous
  /// session is refunded automatically (its keystream rolled back, the row
  /// deleted). A retried message clears `isFailed`, so it survives this sweep —
  /// i.e. failed messages refund themselves on close UNLESS the user retried.
  Future<void> autoRefundAbandonedFailures() async {
    for (final contact in List<Contact>.from(contacts)) {
      final failed = await WiltkeyDatabase.instance.getFailedMessages(
        contact.id,
        masterKeyHex: masterKeyHex,
      );
      for (final msg in failed) {
        await clearFailedMessage(contact, msg);
        log(
          '[Refund] Auto-refunded abandoned failed message ${msg.id} in ${contact.name}',
        );
      }
    }
  }

  Future<bool> retrySendMessage(Contact contact, ChatMessage message) async {
    if (!WebSocketClient().isConnected) return false;

    // Remove old failed message status
    message.isFailed = false;
    notifyListeners();

    // Re-send payload over WebSocket
    final Map<String, dynamic> envelope = {
      't': message.contentType,
      'd': message.text,
      'offset': message.offset,
      'id': message.id,
      if (message.allowSave) 'dl': true,
      if (message.ephemeral) 'eph': 1,
      if (message.ephemeral) 'ttl': message.ttlSeconds,
      // Reply target rides inside the already-encrypted body (message.text).
    };
    final envelopeStr = jsonEncode(envelope);

    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': contact.keyHash,
      'envelope': envelopeStr,
      'content_type': message.contentType,
    });

    await WiltkeyDatabase.instance.saveMessage(
      message,
      contact.id,
      masterKeyHex: masterKeyHex,
    );
    _persistence.saveState(this);
    return true;
  }

  /// Manual / one-shot reconciliation for a 1-on-1 chat. Two directions:
  ///   1. Pull any inbound messages we're missing — ask the peer to resync
  ///      everything past our contiguous incoming pointer (reuses the resync
  ///      that gap-detection fires automatically on a newer message, but here we
  ///      trigger it even when no newer message arrived to expose the gap).
  ///   2. Reconcile our outbound deliveries — send the peer a `delivery_check`
  ///      of our still-undelivered sent messages; they confirm the ones they
  ///      hold (so the tick double-checks) and we resend the ones they're
  ///      missing. This recovers from a lost one-shot delivery receipt (e.g. the
  ///      app was closed past the receipt's relay-queue TTL).
  /// No-op for groups (they have their own multi-candidate resync) and offline.
  Future<bool> syncOneOnOneChat(Contact contact) async {
    if (contact.isGroup) return false;
    await ensureWebSocketConnected();
    if (!WebSocketClient().isConnected) return false;

    // 1. Pull missing inbound history.
    if (contact.incomingMaxOffset > contact.incomingOffset) {
      _requestChatResync(
        contact,
        contact.incomingOffset,
        contact.incomingMaxOffset,
      );
    }

    // 2. Verify outbound deliveries (cap the list so a very stuck chat can't
    // build an oversized frame).
    final undelivered = await WiltkeyDatabase.instance
        .getUndeliveredSentMessages(contact.id);
    final capped = undelivered.length > 200
        ? undelivered.sublist(undelivered.length - 200)
        : undelivered;
    if (capped.isNotEmpty) {
      final items = [
        for (final m in capped) {'id': m.id, 'offset': m.offset},
      ];
      WebSocketClient().sendWSMessage({
        'type': 'SEND_MESSAGE',
        'recipient_id': contact.keyHash,
        'envelope': jsonEncode({'items': items}),
        'content_type': 'delivery_check',
      });
    }
    log(
      '[Delivery Sync] Manual sync for ${contact.name}: pulled inbound, '
      'checked ${capped.length} undelivered message(s)',
    );
    return true;
  }

  /// A peer's message just landed while we're online — the ideal moment to heal
  /// this chat's delivery state without the user hunting for the Sync button. The
  /// peer is demonstrably reachable, so a `delivery_check` for our stuck-on-single
  /// sends will get answered, and any inbound gap can be pulled. Runs [syncOneOnOneChat]
  /// only when there's actually something to fix, and at most one sync per chat at
  /// a time (a burst of arrivals coalesces into one). No-op for groups.
  Future<void> maybeAutoReconcileOnPeerMessage(Contact contact) async {
    if (contact.isGroup) return;
    if (_autoReconcileInFlight.contains(contact.id)) return;

    final hasInboundGap = contact.incomingMaxOffset > contact.incomingOffset;
    bool hasStuckOutbound = false;
    if (!hasInboundGap) {
      final undelivered = await WiltkeyDatabase.instance
          .getUndeliveredSentMessages(contact.id);
      hasStuckOutbound = undelivered.isNotEmpty;
    }
    if (!hasInboundGap && !hasStuckOutbound) return;

    _autoReconcileInFlight.add(contact.id);
    try {
      await syncOneOnOneChat(contact);
      log('[Delivery Sync] Auto-reconciled ${contact.name} on peer arrival.');
    } finally {
      _autoReconcileInFlight.remove(contact.id);
    }
  }

  Future<void> decryptMessage(Contact contact, ChatMessage message) async {
    if (message.decryptedText != null || message.isFailed) return;
    // Plain images are loaded on demand by their thumbnail (from the durable
    // master-key copy, see ChatImageThumbnail / WiltkeyDatabase.loadImageBytes).
    // Never OTP-decrypt them here: a deferred image has an empty `text`, so this
    // would set decryptedText='' + an EMPTY decodedImageBytes and the thumbnail
    // would render that empty cache as a broken image.
    if (message.contentType == 'image') return;
    try {
      final cipherBytes = base64Decode(message.text);
      final plainBytes = contact.isGroup
          ? await WiltkeyOtpService.xorWithGroupKeystream(
              contact.keyHash,
              cipherBytes,
              message.offset,
            )
          : await WiltkeyOtpService.xorWithKeystream(
              contact.keyHash,
              cipherBytes,
              message.offset,
            );
      message.decryptedText = utf8.decode(plainBytes);

      // Cache decoded image bytes if image
      if (message.contentType == 'image') {
        message.decodedImageBytes = base64Decode(message.decryptedText!);
      } else if (message.contentType == 'voice') {
        message.decodedAudioBytes = base64Decode(message.decryptedText!);
      }
      await WiltkeyDatabase.instance.saveMessage(
        message,
        contact.id,
        masterKeyHex: masterKeyHex,
      );
      notifyListeners();
    } catch (e) {
      log('[Crypto Error] Failed to decrypt message ${message.id}: $e');
      message.decryptedText = '[Decryption Failed]';
      notifyListeners();
    }
  }

  Future<void> decryptBatch(Contact contact) async {
    final list = messages[contact.id] ?? [];
    if (list.isEmpty) return;

    // Decrypt the latest 50 messages
    final startIndex = max(0, list.length - 50);
    for (int i = list.length - 1; i >= startIndex; i--) {
      final msg = list[i];
      // Skip plain images — they load lazily via their thumbnail from the master
      // copy. OTP-decrypting a deferred image (empty `text`) here would poison it
      // with an empty decodedImageBytes cache (renders as a broken thumbnail).
      if (msg.contentType == 'image') continue;
      if (msg.decryptedText == null && !msg.isFailed) {
        try {
          final cipherBytes = base64Decode(msg.text);
          final plainBytes = contact.isGroup
              ? await WiltkeyOtpService.xorWithGroupKeystream(
                  contact.keyHash,
                  cipherBytes,
                  msg.offset,
                )
              : await WiltkeyOtpService.xorWithKeystream(
                  contact.keyHash,
                  cipherBytes,
                  msg.offset,
                );
          msg.decryptedText = utf8.decode(plainBytes);
          if (msg.contentType == 'image') {
            msg.decodedImageBytes = base64Decode(msg.decryptedText!);
          } else if (msg.contentType == 'voice') {
            msg.decodedAudioBytes = base64Decode(msg.decryptedText!);
          }
          await WiltkeyDatabase.instance.saveMessage(
            msg,
            contact.id,
            masterKeyHex: masterKeyHex,
          );
        } catch (e) {
          log('[Crypto Error] Failed to decrypt message ${msg.id}: $e');
          msg.decryptedText = '[Decryption Failed]';
        }
      }
    }
    notifyListeners();
  }

  /// Appends a local 'system' note to a chat's history (rendered as a centered
  /// system line, like the "Chat session secure" note). Not sent over the wire.
  Future<void> addSystemMessage(Contact contact, String text) async {
    final msg = ChatMessage(
      id: 'sys_${DateTime.now().microsecondsSinceEpoch}',
      senderId: 'system',
      text: text,
      timestamp: DateTime.now(),
      isSentByMe: false,
      decryptedText: text,
    );
    appendLoadedMessage(contact.id, msg);
    await WiltkeyDatabase.instance.saveMessage(
      msg,
      contact.id,
      masterKeyHex: masterKeyHex,
    );
    notifyListeners();
  }
}
