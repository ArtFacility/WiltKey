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
    // Play flavor: drop our FCM token from the relay first (needs the identity key,
    // which the nuke is about to wipe) so a dead identity can't be pinged.
    await unregisterPushToken();
    // Send NUKE_RECIPIENT command to all contacts to vaporize their side
    for (var contact in contacts) {
      WebSocketClient().sendWSMessage({
        'type': 'NUKE_RECIPIENT',
        'recipient_id': contact.keyHash,
        'nuke_envelope': 'VAPORIZE',
      });
      try {
        if (contact.isGroup) {
          WiltkeyOtpService.clearGroupSeed(contact.keyHash);
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
      // Stop the metadata retry loop for this group — without this, the
      // timer keeps pinging the wiped group's member hashes for ~10 minutes.
      if (isGroup) groupMetaSyncTimers.remove(contact.keyHash)?.cancel();
      if (activeContact?.keyHash == contactKeyHash) {
        activeContact = null;
      }
      try {
        if (isGroup) {
          WiltkeyOtpService.clearGroupSeed(contactKeyHash);
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

      // Activity feed: a chat destroyed by the OTHER side is an orphan event —
      // there's no chat left to hold a note, so it belongs in the feed. Kept
      // generic (no peer/group name — user choice); the UI localizes by type.
      // Also drop any stale feed rows that deep-linked to this now-dead chat.
      await purgeEventsForChat(contactKeyHash);
      if (receivedFromPeer) {
        await logEvent(
          type: isGroup ? 'group_nuked' : 'nuke_received',
          title: isGroup ? 'Group destroyed' : 'Chat destroyed',
          body: isGroup
              ? 'A secure group was destroyed.'
              : 'A secure chat was destroyed.',
        );
      }
    } else {
      // No contact row (e.g. it was already archived/removed but a peer nuke or a
      // retry arrived). We don't know the kind, so best-effort delete both pad
      // name forms — each is a no-op if the file isn't there.
      try {
        WiltkeyOtpService.clearGroupSeed(contactKeyHash);
        await WiltkeyOtpService.deleteKeystreamFile(contactKeyHash);
        await WiltkeyOtpService.deleteGroupKeystreamFile(contactKeyHash);
      } catch (e) {
        log('Error deleting orphan keystream file: $e');
      }
    }

    // This session is gone — drop its pairing stamp so a future re-pair under the
    // same keyHash starts clean (the stale-nuke guard keys off this stamp).
    await _persistence.clearPairingTime(contactKeyHash);

    if (receivedFromPeer) {
      // Send ACK_NUKE to unblock our queue on the server
      log('Sending ACK_NUKE to unblock queue');
      WebSocketClient().sendWSMessage({'type': 'ACK_NUKE'});
    } else if (!isGroup) {
      // Send NUKE_RECIPIENT to vaporize the other side (for 1-on-1 chats only).
      // The envelope carries the issuance time so the recipient can reject this
      // nuke if it arrives after they've re-paired under the same keyHash (a
      // stale nuke that lingered on the relay's 7-day queue). Older clients that
      // ignore the envelope still wipe as before.
      log('Sending NUKE_RECIPIENT to recipient: $contactKeyHash');
      WebSocketClient().sendWSMessage({
        'type': 'NUKE_RECIPIENT',
        'recipient_id': contactKeyHash,
        'nuke_envelope': jsonEncode({
          'cmd': 'VAPORIZE',
          'ts': DateTime.now().millisecondsSinceEpoch,
        }),
      });
    }

    await syncMutedChatsToPrefs();
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
        WiltkeyOtpService.clearGroupSeed(contact.keyHash);
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

  /// A collision-proof local contact id. The old scheme (`contacts.length + 1`)
  /// reused a number after a nuke removed a contact, which could collide with an
  /// existing contact's id — and [WiltkeyDatabase.upsertContact] uses
  /// `ConflictAlgorithm.replace`, so the colliding row was silently overwritten
  /// and its messages orphaned/mixed (the "empty chat after nuke + re-pair" bug).
  /// Deriving from the current MAX id never reuses a live id. Groups keep the `g`
  /// prefix; ids are a local primary key only (the wire uses the keyHash).
  String _nextContactId({required bool isGroup}) {
    int maxN = 0;
    for (final c in contacts) {
      final n = int.tryParse(c.id.replaceFirst(RegExp(r'^g'), '')) ?? 0;
      if (n > maxN) maxN = n;
    }
    final next = maxN + 1;
    return isGroup ? 'g$next' : '$next';
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
    /// FRESH random 256-bit seed for this pairing (the BLE initiator's 'tws').
    /// REQUIRED when recharging an existing 1:1 pad: the pad file is
    /// regenerated from this seed and the offsets reset — under fresh material
    /// that is safe; under the old seed (or the publicly-derivable pubkey
    /// derivation, which the relay can recompute from the AUTH frames) it
    /// would re-encrypt into already-burned keystream. Null is only acceptable
    /// for a brand-new 1:1 contact (or group sync, which keys on the group
    /// seed and is untouched by this parameter).
    String? freshSeedHex,
    void Function(int written, int total)? onPadProgress,
  }) async {
    // Reset nuke status if re-pairing after a nuke — the user is starting fresh
    if (status == AppStatus.nuked) {
      status = AppStatus.normal;
      log('[State] Cleared nuke status on new contact creation.');
    }

    // Security invariant (1:1 only — group sync keys on the group seed):
    // fresh 256-bit seed material is MANDATORY for every 1:1 pad pairing and
    // every recharge. The fallback would be the publicly-derivable pubkey
    // derivation (recomputable by the relay from the AUTH frames), so there
    // is no fallback: missing or malformed seed → fail closed, before any
    // state is mutated.
    if (!isGroup) {
      if (freshSeedHex == null ||
          freshSeedHex.length != 64 ||
          !RegExp(r'^[0-9a-fA-F]+$').hasMatch(freshSeedHex)) {
        throw Exception(
          'Pad pairing refused for $keyHash: no valid fresh seed supplied. '
          'Every 1:1 pairing MUST use fresh 256-bit key material.',
        );
      }
    }
    final seedForPad = (!isGroup)
        ? freshSeedHex!
        : derivedSeed;

    // Replay guard: a 1:1 recharge whose seed matches the EXISTING pad (a
    // replayed/stale 'tws') would regenerate the identical pad and rewind the
    // offsets — re-encrypting into already-burned keystream. The pad's seed
    // is not stored on the contact, so detect it byte-wise: the file head is
    // exactly keystreamRange(seed, 0, …). Fail closed before overwriting.
    if (!isGroup &&
        await WiltkeyOtpService.padMatchesSeed(keyHash, seedForPad)) {
      throw Exception(
        'Pad recharge refused for $keyHash: offered seed matches the '
        'already-burned pad. A recharge MUST use new key material.',
      );
    }

    // On a recharge the existing pad is about to be overwritten — first preserve
    // any received-but-never-opened messages (OTP-only) so they survive as
    // master-key copies. No-op for a brand-new pairing.
    await _preserveMessagesBeforePadReset(keyHash);

    // Generate the keystream file locally (progress bubbles up to the pairing UI).
    await WiltkeyOtpService.generateKeystreamFile(
      keyHash,
      seedForPad,
      bufferBytes,
      onProgress: onPadProgress,
    );

    // Provision the 1-on-1 metadata-channel key. One-way derivation from the
    // pad seed: it encrypts chat_info_update (profile/permissions) but cannot
    // reconstruct the message keystream, so message forward secrecy is kept.
    if (!isGroup) {
      final metaKeyHex = sha256
          .convert(utf8.encode('$seedForPad:meta'))
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
        id: _nextContactId(isGroup: isGroup),
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
    // Stamp this pairing session so a stale `nuke` issued before it can be
    // rejected later (see the nuke branch in [_dispatchIncoming]).
    await _persistence.setPairingTime(
      keyHash,
      DateTime.now().millisecondsSinceEpoch,
    );
    sendProfileUpdateTo(keyHash);
    notifyListeners();
    _persistence.saveState(this);
  }

  /// Creates (or re-pairs) a 1:1 **Time Wilt** chat: a streaming-keystream chat
  /// with a lifetime instead of a byte budget. Unlike [addOrRechargeContact] it
  /// writes NO pad file — it persists the seed ([Contact.streamSeedHex]) and
  /// derives keystream on demand (like groups). [wiltExpiresAt] is the
  /// negotiated ABSOLUTE expiry (identical on both sides); at that instant the
  /// archive sweep flips the chat to read-only. The two directions run on
  /// disjoint, effectively-unbounded lanes so their keystreams never overlap.
  ///
  /// Seed contract: [freshSeedHex] (the BLE initiator's fresh random 'tws') is
  /// REQUIRED whenever this identity may already exist — a re-pair swaps to
  /// unburned key material before the offsets reset, so the reset can never
  /// re-encrypt into the previous era's keystream. Passing no fresh seed for an
  /// existing contact, or a seed identical to the stored one, THROWS.
  Future<void> addOrRechargeTimeWiltContact(
    String name,
    String relayUrl,
    String keyHash,
    String derivedSeed,
    DateTime wiltExpiresAt, {
    String shortNick = '',
    String profileImage = '',
    /// FRESH random 256-bit seed for this pairing (the BLE initiator's 'tws').
    /// The contact's keystream AND meta channel are keyed on this, never on
    /// the deterministic pubkey derivation, when re-pairing: [derivedSeed] is
    /// a pure function of the two pubkeys, so resetting lane offsets under it
    /// would re-encrypt new messages into keystream the previous chat era
    /// already burned (its history is retained, even archived). Fresh material
    /// makes the offset reset safe — the same model as group recharge and the
    /// emergency chat. Null is only acceptable for a brand-new contact.
    String? freshSeedHex,
  }) async {
    if (status == AppStatus.nuked) {
      status = AppStatus.normal;
      log('[State] Cleared nuke status on new Time Wilt contact creation.');
    }

    final seedForContact = (freshSeedHex != null &&
            freshSeedHex.length == 64 &&
            RegExp(r'^[0-9a-fA-F]+$').hasMatch(freshSeedHex))
        ? freshSeedHex
        : null;
    if (seedForContact == null) {
      // No fallback to the deterministic pubkey derivation: the relay sees
      // both pubkeys in the AUTH frames and could recompute that seed and
      // decrypt the whole chat. Fail closed before anything is mutated.
      throw Exception(
        'Time Wilt pairing refused for $keyHash: no valid fresh seed '
        'supplied. Every pairing MUST use fresh 256-bit key material.',
      );
    }

    // Guards BEFORE any state is mutated (a failed re-pair must not leave a
    // half-swapped meta key or contact behind):
    final int existingIndex = contacts.indexWhere((c) => c.keyHash == keyHash);
    if (existingIndex != -1) {
      final existing = contacts[existingIndex];
      // Security invariant: a remote/re-pair can never touch an OTP pad —
      // upserting lane bases over a pad contact would rewind its write pointer.
      if (existing.maxBufferBytes > 0) {
        throw Exception(
          'Time Wilt pairing refused: contact $keyHash holds a one-time pad. '
          'Pad recharging requires in-person BLE pairing.',
        );
      }
      // Security invariant: never rewind offsets under the SAME seed. If the
      // offered seed is the one already burned by this contact, refuse — the
      // caller (or an outdated peer) failed to supply fresh material.
      if (existing.streamSeedHex == seedForContact) {
        throw Exception(
          'Time Wilt re-pair refused for $keyHash: offered seed matches the '
          'already-burned one. A re-pair MUST use fresh key material.',
        );
      }
    }

    // Metadata-channel key (profile/permission updates) — same one-way
    // derivation as byte-budget 1:1; encrypts chat_info_update but cannot
    // reconstruct the message keystream.
    final metaKeyHex = sha256
        .convert(utf8.encode('$seedForContact:meta'))
        .toString();
    await ChatMetaStore.setKey(keyHash, metaKeyHex);

    // Symmetric role by userId compare (not who initiated the pairing): the
    // lower id sends from base 0, the higher from one stride up. Both sides
    // compute the same split, so the lanes are guaranteed disjoint.
    final bool isInitiator = userId.compareTo(keyHash) < 0;
    final int stride = WiltkeyOtpService.kWiltLaneStride;
    final int outBase = isInitiator ? 0 : stride;
    final int inBase = isInitiator ? stride : 0;

    final String contactId = existingIndex != -1
        ? contacts[existingIndex].id
        : _nextContactId(isGroup: false);

    final contact = Contact(
      id: contactId,
      name: name,
      keyHash: keyHash,
      relayUrl: relayUrl,
      isPrivateNode: _isUrlPrivate(relayUrl),
      // No byte budget — Time Wilt is time-bounded, not byte-bounded.
      maxBufferBytes: 0,
      remainingBufferBytes: 0,
      peerRemainingBufferBytes: 0,
      lastActivity: DateTime.now(),
      isWilted: false,
      shortNick: shortNick,
      profileImageB64: profileImage,
      outgoingOffset: outBase,
      outgoingMaxOffset: outBase + stride,
      incomingOffset: inBase,
      incomingMaxOffset: inBase + stride,
      wiltExpiresAt: wiltExpiresAt,
      // A re-pair is a FRESH lifetime — reset the start so the gauge measures
      // now→newExpiry (keeping the old start would leave a huge span and a
      // near-empty gauge even right after re-pairing).
      wiltCreatedAt: DateTime.now(),
      streamSeedHex: seedForContact,
    );

    if (existingIndex != -1) {
      contacts[existingIndex] = contact;
      await WiltkeyDatabase.instance.upsertContact(contact);
    } else {
      contacts.add(contact);
      const note = 'Connected. This is a Time Wilt chat — it wilts to '
          'read-only when its timer runs out.';
      final systemMsg = ChatMessage(
        // 'system' sender → ChatMessage.isSystem true → rendered as a centered
        // system note (not a left/right bubble). Our custom text doesn't match
        // the "Connected. Chat session secure." prefix the byte-budget note uses.
        id: DateTime.now().toString(),
        senderId: 'system',
        text: note,
        timestamp: DateTime.now(),
        isSentByMe: false,
        decryptedText: note,
      );
      messages[contact.id] = [systemMsg];
      loadedChats.add(contact.id);
      hasMoreOlder[contact.id] = false;
      await WiltkeyDatabase.instance.upsertContact(contact);
      await WiltkeyDatabase.instance.saveMessage(
        systemMsg,
        contact.id,
        masterKeyHex: masterKeyHex,
      );
    }

    await _persistence.setPairingTime(
      keyHash,
      DateTime.now().millisecondsSinceEpoch,
    );
    sendProfileUpdateTo(keyHash);
    notifyListeners();
    _persistence.saveState(this);
  }
}
