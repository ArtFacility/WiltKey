part of 'state.dart';

/// Chat lifecycle: self-destruct (1-on-1 + full-mesh group nuke),
/// archive (drop the pad, keep history), pin/local-delete, and the
/// pairing/recharge entry point that (re)provisions a contact + pad.
extension AppStateLifecycle on AppState {
  /// Self-destruct a group on every side: fan `group_nuke` out to every member
  /// we know (full mesh), then wipe locally. The host additionally re-fans on
  /// receipt (see the group_nuke branch in [_dispatchIncoming]) so a spoke that
  /// only knows the host still reaches everyone.
  Future<void> nukeGroup(Contact group) async {
    if (!group.isGroup) return;
    _fanOutGroupNuke(
      group.keyHash,
      group.memberKeyHashes,
      group.hostKeyHash,
      exclude: {userId},
    );
    await nukeContact(group.keyHash, receivedFromPeer: false);
  }

  /// Send `group_nuke` to each member of [groupId] we know, minus [exclude].
  /// The host is always included (idempotent via the Set) so a spoke that knows
  /// only a partial roster still reaches the host, which re-fans to the rest.
  void _fanOutGroupNuke(
    String groupId,
    List<String> memberKeyHashes,
    String? hostKeyHash, {
    required Set<String> exclude,
  }) {
    final targets = <String>{
      for (final m in memberKeyHashes)
        if (m.isNotEmpty && !exclude.contains(m)) m,
    };
    if (hostKeyHash != null &&
        hostKeyHash.isNotEmpty &&
        !exclude.contains(hostKeyHash)) {
      targets.add(hostKeyHash);
    }
    for (final t in targets) {
      WebSocketClient().sendWSMessage({
        'type': 'SEND_MESSAGE',
        'recipient_id': t,
        'envelope': jsonEncode({'group_id': groupId, 'sender_id': userId}),
        'content_type': 'group_nuke',
      });
    }
    log('[GroupNuke] Fanned out to ${targets.length} member(s) for $groupId');
  }

  Future<void> triggerNuke() async {
    status = AppStatus.nuked;
    // Send NUKE_RECIPIENT command to all contacts to vaporize their side
    for (var contact in contacts) {
      WebSocketClient().sendWSMessage({
        'type': 'NUKE_RECIPIENT',
        'recipient_id': contact.keyHash,
        'nuke_envelope': 'VAPORIZE',
      });
      try {
        if (contact.isGroup) {
          WiltkeyOtpService.deleteGroupKeystreamFile(contact.keyHash);
        } else {
          WiltkeyOtpService.deleteKeystreamFile(contact.keyHash);
        }
      } catch (e) {
        log('Error deleting keystream file in triggerNuke: $e');
      }
    }
    contacts.clear();
    messages.clear();
    groupMembersMetadata.clear();
    activeContact = null;
    await WiltkeyDatabase.instance.deleteAll();
    // Belt-and-suspenders: sweep any pad on disk (e.g. orphans, or a group pad
    // whose contact row had already gone) so a self-destruct leaves no key bytes.
    try {
      await WiltkeyOtpService.reconcilePads(<String>{});
    } catch (e) {
      log('Error sweeping pads in triggerNuke: $e');
    }
    notifyListeners();
    await _persistence.clearAll();
  }

  Future<void> nukeContact(
    String contactKeyHash, {
    required bool receivedFromPeer,
  }) async {
    log(
      'nukeContact starting. keyHash: $contactKeyHash, receivedFromPeer: $receivedFromPeer',
    );
    final index = contacts.indexWhere((c) => c.keyHash == contactKeyHash);
    bool isGroup = false;

    if (index != -1) {
      final contact = contacts[index];
      isGroup = contact.isGroup;

      contacts.removeAt(index);
      messages.remove(contact.id);
      loadedChats.remove(contact.id);
      hasMoreOlder.remove(contact.id);
      unreadCounts.remove(contact.id);
      groupMembersMetadata.remove(contact.id);
      if (activeContact?.keyHash == contactKeyHash) {
        activeContact = null;
      }
      try {
        if (isGroup) {
          await WiltkeyOtpService.deleteGroupKeystreamFile(contactKeyHash);
          await GroupDatabase.instance.deleteGroup(contactKeyHash);
          await CustomEmojiStore.clear(contactKeyHash);
          log('Deleted group keystream and database for: $contactKeyHash');
        } else {
          await WiltkeyOtpService.deleteKeystreamFile(contactKeyHash);
          await WiltkeyDatabase.instance.deleteContactRecord(contact.id);
          await ChatMetaStore.clear(contactKeyHash);
          await CustomEmojiStore.clear(contactKeyHash);
          log(
            'Deleted keystream file and DB record for contact: $contactKeyHash',
          );
        }
      } catch (e) {
        log('Error deleting keystream file: $e');
      }
    } else {
      // No contact row (e.g. it was already archived/removed but a peer nuke or a
      // retry arrived). We don't know the kind, so best-effort delete both pad
      // name forms — each is a no-op if the file isn't there.
      try {
        await WiltkeyOtpService.deleteKeystreamFile(contactKeyHash);
        await WiltkeyOtpService.deleteGroupKeystreamFile(contactKeyHash);
      } catch (e) {
        log('Error deleting orphan keystream file: $e');
      }
    }

    if (receivedFromPeer) {
      // Send ACK_NUKE to unblock our queue on the server
      log('Sending ACK_NUKE to unblock queue');
      WebSocketClient().sendWSMessage({'type': 'ACK_NUKE'});
    } else if (!isGroup) {
      // Send NUKE_RECIPIENT to vaporize the other side (for 1-on-1 chats only)
      log('Sending NUKE_RECIPIENT to recipient: $contactKeyHash');
      WebSocketClient().sendWSMessage({
        'type': 'NUKE_RECIPIENT',
        'recipient_id': contactKeyHash,
        'nuke_envelope': 'VAPORIZE',
      });
    }

    notifyListeners();
    await _persistence.saveState(this);
  }

  /// Before a pad is regenerated (recharge) or deleted (archive), make sure every
  /// message that exists ONLY as OTP ciphertext — received but never opened, so it
  /// has no `text_encrypted_master` copy — is decrypted with the still-present pad
  /// and persisted with a master-key copy. Without this, overwriting/deleting the
  /// pad would render those messages permanently undecryptable. No-op for a
  /// first-time pairing (no existing contact) or when the pad is already gone.
  Future<void> _preserveMessagesBeforePadReset(String keyHash) async {
    final idx = contacts.indexWhere((c) => c.keyHash == keyHash);
    if (idx == -1) return;
    final contact = contacts[idx];
    // Query the DB for every OTP-only message (no master-key copy) — NOT just the
    // loaded window — since any unopened message would otherwise become
    // permanently undecryptable once the pad is gone.
    final pending = await WiltkeyDatabase.instance.getOtpOnlyMessages(
      contact.id,
    );
    for (final msg in pending) {
      if (msg.isFailed) continue;
      try {
        final cipherBytes = base64Decode(msg.text);
        final plainBytes = contact.isGroup
            ? await WiltkeyOtpService.xorWithGroupKeystream(
                keyHash,
                cipherBytes,
                msg.offset,
              )
            : await WiltkeyOtpService.xorWithKeystream(
                keyHash,
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
        log('[PadReset] Could not preserve message ${msg.id}: $e');
      }
    }
    // Drop the in-memory window so it reloads with the now-master-decrypted bodies
    // (the old pad these were XOR'd against is about to be replaced/removed).
    loadedChats.remove(contact.id);
    hasMoreOlder.remove(contact.id);
    messages.remove(contact.id);
  }

  /// Archives a chat: drops the OTP pad to reclaim disk space while keeping the
  /// conversation readable. Messages already carry a master-key encrypted copy
  /// (`text_encrypted_master`); any not-yet-opened inbound messages exist only as
  /// OTP ciphertext, so we decrypt those with the still-present pad FIRST, then
  /// delete the pad. The chat becomes read-only (no send/receive) and is tagged
  /// archived. Unlike a nuke, the peer is NOT told — they keep their own copy.
  Future<void> archiveChat(String contactKeyHash) async {
    final index = contacts.indexWhere((c) => c.keyHash == contactKeyHash);
    if (index == -1) return;
    final contact = contacts[index];
    if (contact.isArchived) return;
    log('archiveChat starting for $contactKeyHash (group=${contact.isGroup})');

    // 0. Soft-nuke signal: tell a 1-on-1 peer we've gone read-only so their side
    //    wilts early (history kept, but we'll receive nothing further). Sent over
    //    the metadata channel (survives pad deletion). Groups archive locally only.
    if (!contact.isGroup) {
      await sendArchiveSignal(contact);
    }

    // 1. Make every message recoverable from the master key before the pad goes:
    //    decrypt any OTP-only (unopened inbound) messages with the still-present
    //    pad so they gain a master-key copy.
    await _preserveMessagesBeforePadReset(contact.keyHash);

    // 2. Drop the pad — the only large artifact. Lanes/profiles/emoji are tiny
    //    and stay so archived messages still render member identities/custom
    //    emoji. Custom emoji are intentionally kept (like on recharge).
    try {
      if (contact.isGroup) {
        await WiltkeyOtpService.deleteGroupKeystreamFile(contact.keyHash);
      } else {
        await WiltkeyOtpService.deleteKeystreamFile(contact.keyHash);
      }
    } catch (e) {
      log('[Archive] Error deleting pad: $e');
    }

    // 3. Flip to a read-only archived state and persist.
    final updated = contact.copyWith(
      isArchived: true,
      isWilted: true,
      remainingBufferBytes: 0,
    );
    contacts[index] = updated;
    if (activeContact?.keyHash == contactKeyHash) activeContact = updated;
    await WiltkeyDatabase.instance.upsertContact(updated);
    notifyListeners();
    await _persistence.saveState(this);
    log('[Archive] Chat ${contact.name} archived (pad removed).');
  }

  /// Toggles whether a chat is pinned to the top of the chats list.
  Future<void> togglePin(String contactKeyHash) async {
    final index = contacts.indexWhere((c) => c.keyHash == contactKeyHash);
    if (index == -1) return;
    final updated = contacts[index].copyWith(
      isPinned: !contacts[index].isPinned,
    );
    contacts[index] = updated;
    if (activeContact?.keyHash == contactKeyHash) activeContact = updated;
    await WiltkeyDatabase.instance.upsertContact(updated);
    notifyListeners();
    await _persistence.saveState(this);
  }

  /// Removes an archived chat locally (row + messages + any metadata) without a
  /// remote nuke. The pad is already gone; this is the "delete forever" action
  /// for a chat the user previously archived.
  Future<void> deleteChatLocally(String contactKeyHash) async {
    final index = contacts.indexWhere((c) => c.keyHash == contactKeyHash);
    if (index == -1) return;
    final contact = contacts[index];
    contacts.removeAt(index);
    messages.remove(contact.id);
    loadedChats.remove(contact.id);
    hasMoreOlder.remove(contact.id);
    unreadCounts.remove(contact.id);
    groupMembersMetadata.remove(contact.id);
    if (activeContact?.keyHash == contactKeyHash) activeContact = null;
    try {
      if (contact.isGroup) {
        await WiltkeyOtpService.deleteGroupKeystreamFile(contactKeyHash);
        await GroupDatabase.instance.deleteGroup(contactKeyHash);
        await CustomEmojiStore.clear(contactKeyHash);
      } else {
        await WiltkeyOtpService.deleteKeystreamFile(contactKeyHash);
        await WiltkeyDatabase.instance.deleteContactRecord(contact.id);
        await ChatMetaStore.clear(contactKeyHash);
        await CustomEmojiStore.clear(contactKeyHash);
      }
    } catch (e) {
      log('[Delete] Error removing archived chat: $e');
    }
    notifyListeners();
    await _persistence.saveState(this);
  }

  // Used by BLE Sync to register/recharge contacts
  Future<void> addOrRechargeContact(
    String name,
    String relayUrl,
    int bufferBytes,
    String keyHash, // For group sync, this is the groupId (group keyHash)
    String derivedSeed, {
    String shortNick = '',
    String profileImage = '',
    bool isGroup = false,
    String? hostKeyHash,
    String? hostName,
    String? groupIconHex,
    int? maxMembers,
    int? maxMessageSize,
    bool? imagesAllowed,
  }) async {
    // Reset nuke status if re-pairing after a nuke — the user is starting fresh
    if (status == AppStatus.nuked) {
      status = AppStatus.normal;
      log('[State] Cleared nuke status on new contact creation.');
    }

    // On a recharge the existing pad is about to be overwritten — first preserve
    // any received-but-never-opened messages (OTP-only) so they survive as
    // master-key copies. No-op for a brand-new pairing.
    await _preserveMessagesBeforePadReset(keyHash);

    // Generate the keystream file locally
    await WiltkeyOtpService.generateKeystreamFile(
      keyHash,
      derivedSeed,
      bufferBytes,
    );

    // Provision the 1-on-1 metadata-channel key. One-way derivation from the
    // pad seed: it encrypts chat_info_update (profile/permissions) but cannot
    // reconstruct the message keystream, so message forward secrecy is kept.
    if (!isGroup) {
      final metaKeyHex = sha256
          .convert(utf8.encode('$derivedSeed:meta'))
          .toString();
      await ChatMetaStore.setKey(keyHash, metaKeyHex);
    }

    final bool isInitiator = hostKeyHash != null
        ? userId.compareTo(hostKeyHash) < 0
        : userId.compareTo(keyHash) < 0;
    final int boundary = bufferBytes ~/ 2;

    final int outOffset = isInitiator ? 0 : boundary;
    final int outMax = isInitiator ? boundary : bufferBytes;
    final int inOffset = isInitiator ? boundary : 0;
    final int inMax = isInitiator ? bufferBytes : boundary;

    // For group chats, look up by group keyHash
    int existingIndex = contacts.indexWhere((c) => c.keyHash == keyHash);

    if (existingIndex != -1) {
      final existing = contacts[existingIndex];
      final updatedContact = Contact(
        id: existing.id, // Stitch messages: preserve existing ID
        name: name, // Update in case it was a truncated name from scan
        keyHash: keyHash,
        relayUrl: relayUrl,
        isPrivateNode: _isUrlPrivate(relayUrl),
        maxBufferBytes: bufferBytes,
        remainingBufferBytes: isInitiator
            ? (outMax - outOffset)
            : (bufferBytes - outOffset),
        peerRemainingBufferBytes: inMax - inOffset,
        lastActivity: DateTime.now(),
        isWilted: bufferBytes < 74,
        isGroup: isGroup || existing.isGroup,
        memberCount: isGroup ? maxMembers : existing.memberCount,
        hostName: hostName ?? existing.hostName,
        isHost: existing.isHost,
        hostKeyHash: hostKeyHash ?? existing.hostKeyHash,
        groupIconHex: groupIconHex ?? existing.groupIconHex,
        maxMembers: maxMembers ?? existing.maxMembers,
        maxMessageSize: maxMessageSize ?? existing.maxMessageSize,
        imagesAllowed: imagesAllowed ?? existing.imagesAllowed,
        joinedAt: existing.joinedAt ?? (isGroup ? DateTime.now() : null),
        shortNick: shortNick.isNotEmpty ? shortNick : existing.shortNick,
        profileImageB64: profileImage.isNotEmpty
            ? profileImage
            : existing.profileImageB64,
        outgoingOffset: outOffset,
        outgoingMaxOffset: outMax,
        incomingOffset: inOffset,
        incomingMaxOffset: inMax,
        groupSeed: existing.groupSeed,
        laneSize: existing.laneSize,
        totalGroupSize: existing.totalGroupSize,
        slotIndex: existing.slotIndex,
        additionalSlots: existing.additionalSlots,
      );
      contacts[existingIndex] = updatedContact;
      await WiltkeyDatabase.instance.upsertContact(updatedContact);
    } else {
      final isPrivate = _isUrlPrivate(relayUrl);
      final newContact = Contact(
        id: isGroup
            ? 'g${contacts.length + 1}'
            : (contacts.length + 1).toString(),
        name: name,
        keyHash: keyHash,
        relayUrl: relayUrl,
        isPrivateNode: isPrivate,
        maxBufferBytes: bufferBytes,
        remainingBufferBytes: isInitiator
            ? (outMax - outOffset)
            : (bufferBytes - outOffset),
        peerRemainingBufferBytes: inMax - inOffset,
        lastActivity: DateTime.now(),
        isWilted: bufferBytes < 74,
        isGroup: isGroup,
        memberCount: isGroup ? maxMembers : null,
        hostName: hostName,
        isHost: false, // Joiners are always Spokes (not Hosts)
        hostKeyHash: hostKeyHash,
        groupIconHex: groupIconHex,
        maxMembers: maxMembers,
        maxMessageSize: maxMessageSize,
        imagesAllowed: imagesAllowed,
        joinedAt: isGroup ? DateTime.now() : null,
        shortNick: shortNick,
        profileImageB64: profileImage,
        outgoingOffset: outOffset,
        outgoingMaxOffset: outMax,
        incomingOffset: inOffset,
        incomingMaxOffset: inMax,
      );
      contacts.add(newContact);
      final systemMsg = ChatMessage(
        id: DateTime.now().toString(),
        senderId: isGroup ? 'system' : newContact.id,
        text: isGroup
            ? 'Joined group "$name". Connections secure.'
            : 'Connected. Chat session secure.',
        timestamp: DateTime.now(),
        isSentByMe: false,
        decryptedText: isGroup
            ? 'Joined group "$name". Connections secure.'
            : 'Connected. Chat session secure.',
      );
      // A brand-new chat's full history is this one line, so mark its window
      // loaded — opening it shows the note immediately (no DB round-trip).
      messages[newContact.id] = [systemMsg];
      loadedChats.add(newContact.id);
      hasMoreOlder[newContact.id] = false;
      await WiltkeyDatabase.instance.upsertContact(newContact);
      await WiltkeyDatabase.instance.saveMessage(
        systemMsg,
        newContact.id,
        masterKeyHex: masterKeyHex,
      );
    }
    notifyListeners();
    _persistence.saveState(this);
  }
}
