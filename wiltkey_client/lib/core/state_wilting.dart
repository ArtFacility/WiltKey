part of 'state.dart';

/// Wilting (disappearing) messages — the client-side engine.
///
/// A wilting message carries only its config on the OTP envelope (`eph`, `ttl`);
/// all timing is resolved on the recipient's device. The recipient taps to
/// reveal ([revealEphemeral]) — that stamps `openedAt`/`expiresAt` and arms a
/// countdown. When the countdown fires (or the app finds it already elapsed on a
/// later launch), the message "wilts": [WiltkeyDatabase.wiltMessageRow] blanks
/// its stored ciphertext in place and the in-memory copy is cleared, so no
/// recoverable content survives.
///
/// Cooperative by nature (a modified peer can't be forced to wilt), but WiltKey's
/// FLAG_SECURE + consensual screenshots close the usual retention routes. This is
/// the local engine only — the cross-peer "wilt confirmation" signal (`wilted_by`)
/// and the reveal/countdown UI ride on top of it in later phases.
extension AppStateWilting on AppState {
  /// Recipient reveals a wilting message: stamps the open/expiry instants (once),
  /// persists them, arms the countdown, and refreshes the bubble. No-op for a
  /// non-ephemeral, already-opened, or already-wilted message.
  Future<void> revealEphemeral(Contact contact, ChatMessage msg) async {
    if (!msg.ephemeral || msg.wilted) return;
    if (msg.openedAt != null) {
      // Already ticking (e.g. reopened before expiry) — just ensure a timer.
      final exp = msg.expiresAt;
      if (exp != null) _armWiltTimer(contact.id, msg.id, exp);
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final ttlMs = (msg.ttlSeconds <= 0 ? 5 : msg.ttlSeconds) * 1000;
    final expires = now + ttlMs;
    msg.openedAt = now;
    msg.expiresAt = expires;
    await WiltkeyDatabase.instance.markMessageOpened(msg.id, now, expires);
    _armWiltTimer(contact.id, msg.id, expires);
    notifyListeners();
  }

  /// Destroy a wilting message now: blank the DB row, clear the in-memory copy if
  /// it's loaded, drop its timer, and rebuild. Idempotent. When *we* were the
  /// recipient (not the author), emits a `wilt_done` confirmation to the sender so
  /// their copy can wilt too / tally the group `wilted_by`.
  Future<void> wiltMessage(String chatId, String messageId) async {
    _cancelWiltTimer(messageId);

    // Grab ownership BEFORE destroying, so we know whether to confirm even when
    // the chat isn't loaded (a cold-start sweep). In-memory first, else the DB.
    ChatMessage? inMem;
    final list = messages[chatId];
    if (list != null) {
      for (final m in list) {
        if (m.id == messageId) {
          inMem = m;
          break;
        }
      }
    }
    final bool alreadyWilted = inMem?.wilted ?? false;
    // Control cards (screenshot_request) expire via this engine but never emit a
    // wilt confirmation — only real received message content does.
    final bool shouldConfirm = inMem != null
        ? (inMem.ephemeral &&
              !inMem.isSentByMe &&
              !inMem.wilted &&
              inMem.contentType != 'screenshot_request')
        : await WiltkeyDatabase.instance.isReceivedEphemeral(messageId);

    await WiltkeyDatabase.instance.wiltMessageRow(messageId);
    if (inMem != null && !inMem.wilted) inMem.wiltInMemory();
    notifyListeners();

    if (shouldConfirm && !alreadyWilted) {
      final contact = _contactForChat(chatId);
      if (contact != null) await _sendWiltConfirmation(contact, messageId);
    }
  }

  Contact? _contactForChat(String chatId) {
    final i = contacts.indexWhere((c) => c.id == chatId);
    return i == -1 ? null : contacts[i];
  }

  /// Recipient → sender confirmation that a wilting message was destroyed on our
  /// device. Rides the AES meta channel (never the OTP pad), like reactions:
  /// 1-on-1 `wilt_done` over the peer's meta key; group `group_wilt_done` keyed
  /// by SHA256(groupSeed), sent full-mesh so every copy can tally.
  Future<void> _sendWiltConfirmation(Contact contact, String targetId) async {
    final payload = jsonEncode({'target_id': targetId, 'v': 1});
    try {
      if (contact.isGroup) {
        final seed = contact.groupSeed ?? '';
        if (seed.isEmpty) return;
        final keyHex = sha256.convert(utf8.encode(seed)).toString();
        final enc = WiltkeyPersistence().encryptString(payload, keyHex);
        final envelope = jsonEncode({
          'group_id': contact.keyHash,
          'sender_id': userId,
          'd': enc,
          't': 'group_wilt_done',
        });
        await ensureWebSocketConnected();
        for (final memberHash in contact.memberKeyHashes) {
          if (memberHash == userId) continue;
          WebSocketClient().sendWSMessage({
            'type': 'SEND_MESSAGE',
            'recipient_id': memberHash,
            'envelope': envelope,
            'content_type': 'group_wilt_done',
          });
        }
      } else {
        final metaKeyHex = await ChatMetaStore.keyFor(contact.keyHash);
        if (metaKeyHex == null) return;
        await ensureWebSocketConnected();
        final enc = WiltkeyPersistence().encryptString(payload, metaKeyHex);
        WebSocketClient().sendWSMessage({
          'type': 'SEND_MESSAGE',
          'recipient_id': contact.keyHash,
          'envelope': jsonEncode({'d': enc}),
          'content_type': 'wilt_done',
        });
      }
    } catch (e) {
      log('[Wilt] Failed to send confirmation: $e');
    }
  }

  /// Inbound 1-on-1 `wilt_done`: the peer wilted a message we sent them. Record
  /// the confirmation and wilt our own copy (the single peer has destroyed theirs).
  Future<void> _handleWiltDone(String senderId, String envelopeStr) async {
    final idx = contacts.indexWhere((c) => c.keyHash == senderId && !c.isGroup);
    if (idx == -1) return;
    final contact = contacts[idx];
    final metaKeyHex = await ChatMetaStore.keyFor(senderId);
    if (metaKeyHex == null) return;
    try {
      final outer = jsonDecode(envelopeStr) as Map<String, dynamic>;
      final dec = WiltkeyPersistence().decryptString(
        outer['d'] as String,
        metaKeyHex,
      );
      final p = jsonDecode(dec) as Map<String, dynamic>;
      final targetId = p['target_id'] as String?;
      if (targetId == null) return;
      await _recordWiltedBy(contact, targetId, senderId);
      await wiltMessage(contact.id, targetId); // our copy wilts too (self-authored → no re-confirm)
    } catch (e) {
      log('[Wilt] Bad wilt_done: $e');
    }
  }

  /// Inbound group `group_wilt_done`: a member wilted a copy of some message.
  /// Tally them in `wilted_by`; once every other member has confirmed, wilt our
  /// own copy too.
  Future<void> _handleGroupWiltDone(
    Contact group,
    String senderId,
    Map<String, dynamic> envelopeJson,
  ) async {
    try {
      final seed = group.groupSeed ?? '';
      if (seed.isEmpty) return;
      final keyHex = sha256.convert(utf8.encode(seed)).toString();
      final dec = WiltkeyPersistence().decryptString(
        envelopeJson['d'] as String,
        keyHex,
      );
      final p = jsonDecode(dec) as Map<String, dynamic>;
      final targetId = p['target_id'] as String?;
      if (targetId == null) return;
      final set = await _recordWiltedBy(group, targetId, senderId);
      if (set == null) return;
      // Every OTHER member has confirmed → our copy has served its purpose.
      final others = group.memberKeyHashes.where((h) => h != userId).toSet();
      if (others.isNotEmpty && others.difference(set).isEmpty) {
        await wiltMessage(group.id, targetId);
      }
    } catch (e) {
      log('[Wilt] Bad group_wilt_done: $e');
    }
  }

  /// Persist a peer into a message's `wilted_by` set and refresh the loaded copy.
  /// Returns the updated set, or null if the target isn't stored.
  Future<Set<String>?> _recordWiltedBy(
    Contact contact,
    String targetId,
    String reactorId,
  ) async {
    final updated = await WiltkeyDatabase.instance.addWiltedBy(
      targetId,
      reactorId,
    );
    if (updated == null) return null;
    final list = messages[contact.id];
    if (list != null) {
      for (final m in list) {
        if (m.id == targetId) {
          m.wiltedBy = updated;
          break;
        }
      }
    }
    notifyListeners();
    return updated;
  }

  /// One-shot (per unlock) sweep over every not-yet-wilted ephemeral message:
  /// destroys any whose countdown already elapsed while the app was closed, and
  /// arms live timers for the rest. Unopened messages (no expiry yet) persist
  /// until the recipient reveals them. Safe to call repeatedly; the [AppState]
  /// `wiltSwept` guard makes only the first call per session do the DB scan, but
  /// the resume path passes [force] to re-arm timers dropped on background.
  Future<void> sweepAndArmWilting({bool force = false}) async {
    if (wiltSwept && !force) return;
    wiltSwept = true;
    final pending = await WiltkeyDatabase.instance.getPendingWiltMessages();
    if (pending.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in pending) {
      final exp = row.expiresAt;
      if (exp == null) continue; // unopened — persists until revealed
      if (now >= exp) {
        await wiltMessage(row.chatId, row.id);
      } else {
        _armWiltTimer(row.chatId, row.id, exp);
      }
    }
  }

  /// (Re)arm the countdown for one opened message. Cancels any existing timer for
  /// the same id first so a re-arm never double-fires.
  void _armWiltTimer(String chatId, String messageId, int expiresAtMs) {
    _cancelWiltTimer(messageId);
    final delayMs = expiresAtMs - DateTime.now().millisecondsSinceEpoch;
    if (delayMs <= 0) {
      // Already elapsed — wilt on the next microtask (avoid reentrancy here).
      Future.microtask(() => wiltMessage(chatId, messageId));
      return;
    }
    wiltTimers[messageId] = Timer(
      Duration(milliseconds: delayMs),
      () => wiltMessage(chatId, messageId),
    );
  }

  void _cancelWiltTimer(String messageId) {
    wiltTimers.remove(messageId)?.cancel();
  }

  /// Drop every armed countdown (on lock / nuke). Does not wilt anything — the
  /// persisted `expires_at` lets the next sweep resume where this left off.
  void cancelAllWiltTimers() {
    for (final t in wiltTimers.values) {
      t.cancel();
    }
    wiltTimers.clear();
    wiltSwept = false;
  }
}
