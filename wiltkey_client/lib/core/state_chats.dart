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

  /// Bumps a chat's unread count for a freshly-arrived inbound message, unless
  /// that chat is the one currently open. Control writes / system lines never
  /// count. Call only for live arrivals (not historical resync replays).
  void bumpUnread(Contact contact, ChatMessage msg) {
    if (msg.isSentByMe || msg.isSystem) return;
    if (msg.contentType == 'emoji_def' || msg.contentType == 'emoji_delete')
      return;
    if (activeContact?.id == contact.id) return; // user is reading it
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
    lastReadMs[contact.id] =
        DateTime.now().millisecondsSinceEpoch; // clear unread on open
    unreadCounts.remove(contact.id);
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

    final payloadBytes = utf8.encode(text).length;

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
      decryptedText: text, // original plaintext cached in-memory
    );
    appendLoadedMessage(contact.id, newMessage);
    notifyListeners();

    // Self-heal the socket, then encrypt — the slow steps the placeholder hides.
    await ensureWebSocketConnected();

    List<int> cipherBytes;
    try {
      final rawBytes = utf8.encode(text);
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

  Future<void> decryptMessage(Contact contact, ChatMessage message) async {
    if (message.decryptedText != null || message.isFailed) return;
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
