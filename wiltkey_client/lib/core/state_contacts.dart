part of 'state.dart';

/// Contact request payload sent over the AES meta channel.
class ContactRequestPayload {
  final int v = 1;
  final String requestId;
  final String requesterName;
  final String requesterShortNick;
  final String? requesterProfileImageB64;
  final String? requesterAvatarBorderId;
  final String requesterPubkey;
  final String sharedSecretSeed;

  ContactRequestPayload({
    required this.requestId,
    required this.requesterName,
    required this.requesterShortNick,
    this.requesterProfileImageB64,
    this.requesterAvatarBorderId,
    required this.requesterPubkey,
    required this.sharedSecretSeed,
  });

  Map<String, dynamic> toJson() => {
    'v': v,
    'request_id': requestId,
    'requester_name': requesterName,
    'requester_short_nick': requesterShortNick,
    if (requesterProfileImageB64 != null)
      'requester_profile_image_b64': requesterProfileImageB64,
    if (requesterAvatarBorderId != null)
      'requester_avatar_border_id': requesterAvatarBorderId,
    'requester_pubkey': requesterPubkey,
    'shared_secret_seed': sharedSecretSeed,
  };

  factory ContactRequestPayload.fromJson(Map<String, dynamic> json) =>
      ContactRequestPayload(
        requestId: json['request_id'] as String,
        requesterName: json['requester_name'] as String,
        requesterShortNick: json['requester_short_nick'] as String,
        requesterProfileImageB64: json['requester_profile_image_b64'] as String?,
        requesterAvatarBorderId: json['requester_avatar_border_id'] as String?,
        requesterPubkey: json['requester_pubkey'] as String,
        sharedSecretSeed: json['shared_secret_seed'] as String,
      );
}

/// Contact response payload sent over the AES meta channel.
class ContactResponsePayload {
  final int v = 1;
  final String requestId;
  final bool accept;
  final String? responderName;
  final String? responderShortNick;
  final String? responderProfileImageB64;
  final String? responderAvatarBorderId;
  final String? responderPubkey;
  final String? sharedSecretSeed;

  ContactResponsePayload({
    required this.requestId,
    required this.accept,
    this.responderName,
    this.responderShortNick,
    this.responderProfileImageB64,
    this.responderAvatarBorderId,
    this.responderPubkey,
    this.sharedSecretSeed,
  });

  Map<String, dynamic> toJson() => {
    'v': v,
    'request_id': requestId,
    'accept': accept,
    if (responderName != null) 'responder_name': responderName,
    if (responderShortNick != null) 'responder_short_nick': responderShortNick,
    if (responderProfileImageB64 != null)
      'responder_profile_image_b64': responderProfileImageB64,
    if (responderAvatarBorderId != null)
      'responder_avatar_border_id': responderAvatarBorderId,
    if (responderPubkey != null) 'responder_pubkey': responderPubkey,
    if (sharedSecretSeed != null) 'shared_secret_seed': sharedSecretSeed,
  };

  factory ContactResponsePayload.fromJson(Map<String, dynamic> json) =>
      ContactResponsePayload(
        requestId: json['request_id'] as String,
        accept: json['accept'] as bool,
        responderName: json['responder_name'] as String?,
        responderShortNick: json['responder_short_nick'] as String?,
        responderProfileImageB64: json['responder_profile_image_b64'] as String?,
        responderAvatarBorderId: json['responder_avatar_border_id'] as String?,
        responderPubkey: json['responder_pubkey'] as String?,
        sharedSecretSeed: json['shared_secret_seed'] as String?,
      );
}

/// In-memory pending contact request (for the requester's chat card UI).
class PendingContactRequest {
  final String requestId;
  final String targetKeyHash;
  final String targetName;
  final DateTime sentAt;
  String status; // 'pending' | 'accepted' | 'declined'

  PendingContactRequest({
    required this.requestId,
    required this.targetKeyHash,
    required this.targetName,
    required this.sentAt,
    this.status = 'pending',
  });
}

extension AppStateContacts on AppState {
  /// How long a stored social-contact profile snapshot is considered fresh.
  /// Older snapshots get a profile_update_request on startup.
  static const Duration kProfileFreshness = Duration(days: 7);

  /// Load social contacts from DB into memory. Called on startup.
  Future<void> loadSocialContacts() async {
    try {
      final rows = await WiltkeyDatabase.instance.getAllSocialContacts();
      socialContacts = rows;
      notifyListeners();
      // Fire-and-forget: poke stale peers (>7 days) to refresh our copy of
      // their profile. Non-blocking; each send is independent.
      _maybeRefreshStaleProfiles();
    } catch (e) {
      log('[Contacts] load failed: $e');
    }
  }

  /// Request a fresh profile_update from peers whose stored snapshot is older
  /// than [kProfileFreshness]. Silent when nothing is stale.
  Future<void> _maybeRefreshStaleProfiles() async {
    final cutoff =
        DateTime.now().millisecondsSinceEpoch -
        kProfileFreshness.inMilliseconds;
    for (final c in socialContacts) {
      if ((c.lastSyncedAt ?? 0) < cutoff) {
        sendProfileUpdateRequest(c.keyHash);
      }
    }
  }

  /// Send a contact request to an existing 1-on-1 chat peer.
  /// The request is sent over the AES meta channel (not the OTP pad); the sent
  /// control card is inserted into this chat. Returns null on success, else a
  /// pre-localized error string.
  Future<String?> sendContactRequest(Contact contact) async {
    if (contact.isGroup) {
      return 'Contact requests target individual users';
    }
    return sendContactRequestToKey(
      keyHash: contact.keyHash,
      name: contact.name,
      chatContact: contact,
    );
  }

  /// Send a contact request targeting [keyHash] (a 1:1 peer OR a group member)
  /// over the AES meta channel. The request is addressed to exactly one peer —
  /// it is never fanned out to the rest of a group. When [chatContact] is a
  /// direct 1:1 chat, a sent control card is inserted there so the sender can
  /// watch the request resolve; without one the request still goes out but has
  /// no in-chat card to live in.
  Future<String?> sendContactRequestToKey({
    required String keyHash,
    required String name,
    Contact? chatContact,
  }) async {
    if (keyHash == userId) {
      return 'You cannot add yourself';
    }
    // Check if already a social contact
    if (socialContacts.any((c) => c.keyHash == keyHash)) {
      return 'Already in your contacts';
    }
    // Check if blocked locally
    if (await WiltkeyDatabase.instance.isContactBlocked(keyHash)) {
      return 'This user is blocked';
    }

    final metaKeyHex = await ChatMetaStore.keyFor(keyHash);
    if (metaKeyHex == null) {
      return 'This chat predates the metadata channel — re-pair to enable contact requests';
    }

    final requestId = _newContactRequestId();
    final sharedSecretSeed = _deriveSharedSecretSeed(keyHash);

    final payload = ContactRequestPayload(
      requestId: requestId,
      requesterName: effectiveDeviceName,
      requesterShortNick: effectiveShortNick,
      requesterProfileImageB64: profileImageB64.isNotEmpty ? profileImageB64 : null,
      requesterAvatarBorderId: equippedAvatarBorderId,
      requesterPubkey: publicKeyHex,
      sharedSecretSeed: sharedSecretSeed,
    );

    await ensureWebSocketConnected();

    final enc = WiltkeyPersistence().encryptString(
      jsonEncode(payload.toJson()),
      metaKeyHex,
    );

    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': keyHash,
      'envelope': jsonEncode({'d': enc}),
      'content_type': 'contact_request',
    });

    // Track pending request for UI
    _pendingContactRequests[requestId] = PendingContactRequest(
      requestId: requestId,
      targetKeyHash: keyHash,
      targetName: name,
      sentAt: DateTime.now(),
    );

    // Insert a local system message card in the direct chat (sent by us)
    if (chatContact != null) {
      await _insertContactRequestSentCard(chatContact, requestId, keyHash, name);
    }

    notifyListeners();
    return null;
  }

  /// Handle inbound contact request (receiver side).
  Future<void> _handleContactRequest(
    String senderId,
    String envelopeStr,
  ) async {
    final idx = contacts.indexWhere((c) => c.keyHash == senderId);
    if (idx == -1) return;
    final contact = contacts[idx];
    if (contact.isGroup) return; // 1-on-1 only

    // Check if blocked
    if (await WiltkeyDatabase.instance.isContactBlocked(senderId)) {
      return; // Silently drop
    }

    final metaKeyHex = await ChatMetaStore.keyFor(senderId);
    if (metaKeyHex == null) return;

    try {
      final outer = jsonDecode(envelopeStr) as Map<String, dynamic>;
      final dec = WiltkeyPersistence().decryptString(
        outer['d'] as String,
        metaKeyHex,
      );
      final p = jsonDecode(dec) as Map<String, dynamic>;
      final payload = ContactRequestPayload.fromJson(p);

      // Verify the shared secret seed matches our derivation
      final expectedSeed = _deriveSharedSecretSeed(senderId);
      if (payload.sharedSecretSeed != expectedSeed) {
        log('[ContactRequest] Shared secret mismatch — possible tampering');
        return;
      }

      // Insert a system message card in the chat with Approve/Deny buttons
      await _insertContactRequestReceivedCard(contact, payload, senderId);

      // Surface in the activity feed so it's not missed when the user is in
      // other chats. Deep-links to this chat (the card lives in it). The event
      // id is the request id, so a redelivered frame can't double-log.
      await logEvent(
        id: 'contact_request_${payload.requestId}',
        type: 'contact_request',
        title: payload.requesterName,
        body: 'sent you a contact request',
        chatKey: senderId,
      );
    } catch (e) {
      log('[ContactRequest Error] $e');
    }
  }

  /// Handle inbound contact response (requester side).
  Future<void> _handleContactResponse(
    String senderId,
    String envelopeStr,
  ) async {
    final metaKeyHex = await ChatMetaStore.keyFor(senderId);
    if (metaKeyHex == null) return;

    try {
      final outer = jsonDecode(envelopeStr) as Map<String, dynamic>;
      final dec = WiltkeyPersistence().decryptString(
        outer['d'] as String,
        metaKeyHex,
      );
      final p = jsonDecode(dec) as Map<String, dynamic>;
      final payload = ContactResponsePayload.fromJson(p);

      final requestId = payload.requestId;
      final pending = _pendingContactRequests[requestId];
      if (pending == null) return; // Not our request

      if (payload.accept) {
        // Peer accepted — create social contact on our side too
        if (!socialContacts.any((c) => c.keyHash == senderId)) {
          final sharedSecret = _deriveSharedSecretSeed(senderId);
          final sc = SocialContact(
            id: 0, // DB assigns
            keyHash: senderId,
            name: payload.responderName ?? 'Contact',
            shortNick: payload.responderShortNick,
            profileImageB64: payload.responderProfileImageB64,
            avatarBorderId: payload.responderAvatarBorderId,
            sharedSecretSeed: sharedSecret,
            myPubkey: publicKeyHex,
            peerPubkey: payload.responderPubkey ?? '',
            addedAt: DateTime.now().millisecondsSinceEpoch,
            isBlocked: false,
            lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
          );
          await WiltkeyDatabase.instance.insertSocialContact(sc);
          socialContacts.insert(0, sc);
        }
        pending.status = 'accepted';

        // Update 1:1 chat contact decor immediately
        final cIdx = contacts.indexWhere((c) => c.keyHash == senderId && !c.isGroup);
        if (cIdx != -1) {
          contacts[cIdx] = contacts[cIdx].copyWith(
            name: payload.responderName ?? contacts[cIdx].name,
            shortNick: payload.responderShortNick,
            profileImageB64: payload.responderProfileImageB64,
            avatarBorderId: payload.responderAvatarBorderId,
          );
          await WiltkeyDatabase.instance.upsertContact(contacts[cIdx]);
        }

        // Send our own full profile snapshot back immediately
        sendProfileUpdateTo(senderId);
      } else {
        pending.status = 'declined';
      }

      // Update the local sent card (it lives in our direct chat with the peer)
      final idx = contacts.indexWhere((c) => c.keyHash == senderId && !c.isGroup);
      if (idx != -1) {
        await _updateContactRequestSentCard(contacts[idx], requestId, pending.status);
      }
      _pendingContactRequests.remove(requestId);
      notifyListeners();
    } catch (e) {
      log('[ContactResponse Error] $e');
    }
  }

  /// Respond to a contact request (receiver taps Approve/Deny).
  Future<void> respondToContactRequest(
    Contact contact,
    String requestId,
    bool accept,
  ) async {
    final metaKeyHex = await ChatMetaStore.keyFor(contact.keyHash);
    if (metaKeyHex == null) return;

    final payload = ContactResponsePayload(
      requestId: requestId,
      accept: accept,
      responderName: accept ? effectiveDeviceName : null,
      responderShortNick: accept ? effectiveShortNick : null,
      responderProfileImageB64: accept && profileImageB64.isNotEmpty ? profileImageB64 : null,
      responderAvatarBorderId: accept ? equippedAvatarBorderId : null,
      responderPubkey: accept ? publicKeyHex : null,
      sharedSecretSeed: accept ? _deriveSharedSecretSeed(contact.keyHash) : null,
    );

    await ensureWebSocketConnected();

    final enc = WiltkeyPersistence().encryptString(
      jsonEncode(payload.toJson()),
      metaKeyHex,
    );

    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': contact.keyHash,
      'envelope': jsonEncode({'d': enc}),
      'content_type': 'contact_response',
    });

    if (accept) {
      // Create social contact locally
      if (!socialContacts.any((c) => c.keyHash == contact.keyHash)) {
        final sc = SocialContact(
          id: 0,
          keyHash: contact.keyHash,
          name: contact.name,
          shortNick: contact.shortNick,
          profileImageB64: contact.profileImageB64,
          avatarBorderId: contact.avatarBorderId,
          sharedSecretSeed: _deriveSharedSecretSeed(contact.keyHash),
          myPubkey: publicKeyHex,
          peerPubkey: contact.keyHash,
          addedAt: DateTime.now().millisecondsSinceEpoch,
          isBlocked: false,
          lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await WiltkeyDatabase.instance.insertSocialContact(sc);
        socialContacts.insert(0, sc);
      }
      // Update the received card to "accepted"
      await _updateContactRequestReceivedCard(contact, requestId, 'accepted');

      // Send our full profile snapshot to them immediately
      sendProfileUpdateTo(contact.keyHash);
    } else {
      // Update the received card to "declined"
      await _updateContactRequestReceivedCard(contact, requestId, 'declined');
    }

    notifyListeners();
  }

  /// Remove a social contact (and notify peer? — for now local only).
  Future<void> removeSocialContact(String keyHash) async {
    await WiltkeyDatabase.instance.deleteSocialContact(keyHash);
    socialContacts.removeWhere((c) => c.keyHash == keyHash);
    notifyListeners();
  }

  /// Block a peer — adds to local block list, removes from contacts, and sends a
  /// `contact_block` notice over the AES meta channel so the peer deletes us on
  /// their end too (blocking deletes on both sides).
  Future<void> blockContact(String keyHash) async {
    // Remove from social contacts if present
    await removeSocialContact(keyHash);

    // Add to block list
    final block = ContactBlock(
      id: 0,
      keyHash: keyHash,
      blockedAt: DateTime.now().millisecondsSinceEpoch,
      reason: null,
    );
    await WiltkeyDatabase.instance.insertContactBlock(block);
    // Notify the peer (best-effort; silent if the chat predates the meta channel).
    await sendContactBlock(keyHash);
    notifyListeners();
  }

  /// Unblock a peer.
  Future<void> unblockContact(String keyHash) async {
    await WiltkeyDatabase.instance.deleteContactBlock(keyHash);
    notifyListeners();
  }

  /// Send a `contact_block` notice ("contact nuke") to [keyHash] over the AES
  /// meta channel. The payload carries the key hash plus the shared secret seed
  /// (which both sides derive identically) so the receiver can verify the nuke
  /// came from the real peer before deleting us.
  Future<void> sendContactBlock(String keyHash) async {
    final metaKeyHex = await ChatMetaStore.keyFor(keyHash);
    if (metaKeyHex == null) return;
    await ensureWebSocketConnected();
    final enc = WiltkeyPersistence().encryptString(
      jsonEncode({
        'v': 1,
        'kh': keyHash,
        's': _deriveSharedSecretSeed(keyHash),
        'ts': DateTime.now().millisecondsSinceEpoch,
      }),
      metaKeyHex,
    );
    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': keyHash,
      'envelope': jsonEncode({'d': enc}),
      'content_type': 'contact_block',
    });
  }

  /// Handle inbound `contact_block` — the peer blocked us, so delete them from
  /// our contacts (the block deletes on both ends). We do NOT auto-block them;
  /// they can re-add us later.
  Future<void> _handleContactBlock(String senderId, String envelopeStr) async {
    final metaKeyHex = await ChatMetaStore.keyFor(senderId);
    if (metaKeyHex == null) return;
    try {
      final outer = jsonDecode(envelopeStr) as Map<String, dynamic>;
      final dec = WiltkeyPersistence().decryptString(
        outer['d'] as String,
        metaKeyHex,
      );
      final p = jsonDecode(dec) as Map<String, dynamic>;
      // Tamper check: the seed must match our own derivation of this pair. Both
      // sides sort the same two key hashes, so a genuine nuke always matches.
      if (p['s'] != _deriveSharedSecretSeed(senderId)) {
        log('[ContactBlock] Shared secret mismatch — possible tampering');
        return;
      }
      final ts = p['ts'] as int?;
      if (ts != null) {
        final pairedAt = await _persistence.getPairingTime(senderId);
        if (pairedAt != null && pairedAt > ts) {
          log('[ContactBlock] Ignoring STALE contact_block from $senderId');
          return;
        }
      }
    } catch (_) {
      return;
    }
    final idx = socialContacts.indexWhere((c) => c.keyHash == senderId);
    if (idx == -1) return;
    final name = socialContacts[idx].name;
    await removeSocialContact(senderId);
    // Surface in the activity feed so a vanished contact isn't a mystery.
    await logEvent(
      id: 'contact_removed_$senderId',
      type: 'contact_removed',
      title: name,
      body: 'removed you from their contacts',
      chatKey: senderId,
    );
  }

  /// Lifetime (seconds) of an emergency chat — always 12 hours.
  static const int kEmergencyChatLifetimeSecs = 12 * 60 * 60;

  /// Outer content type for the emergency-chat creation frame.
  static const String kEmergencyChatContentType = 'emergency_chat';

  /// Outer content type for the emergency-chat acknowledgment frame.
  static const String kEmergencyChatAckContentType = 'emergency_chat_ack';

  /// Create a 12-hour Time Wilt chat with [keyHash] WITHOUT meeting in person.
  ///
  /// Destructive recharge: replaces any existing active, wilted, or archived chat
  /// and wipes old message history. A fresh 256-bit keystream seed is generated
  /// and sent to the peer inside an AES meta-channel envelope.
  ///
  /// The chat is initially marked [isPendingEmergency = true] (unclickable on
  /// dashboard) until the peer responds with an `emergency_chat_ack` signal.
  /// Returns null on success, or a user-facing error string.
  Future<String?> createEmergencyChat(String keyHash) async {
    if (await WiltkeyDatabase.instance.isContactBlocked(keyHash)) {
      return 'This user is blocked';
    }
    final metaKeyHex = await ChatMetaStore.keyFor(keyHash);
    if (metaKeyHex == null) {
      return 'No meta channel to $keyHash — cannot create an emergency chat';
    }

    final now = DateTime.now();
    final seed = _newEmergencySeed();
    final expiry = now.add(Duration(seconds: kEmergencyChatLifetimeSecs));

    // Create local pending emergency chat (wipes old chat history & keystream)
    await _applyEmergencyChat(
      keyHash,
      seed,
      expiry,
      isPending: true,
      isInitiatorSide: true,
    );

    // Transmit emergency chat request to peer
    await ensureWebSocketConnected();
    final enc = WiltkeyPersistence().encryptString(
      jsonEncode({
        'v': 1,
        'seed': seed,
        'wilt_expires_at_ms': expiry.millisecondsSinceEpoch,
        'sender_name': effectiveDeviceName,
        'relay_url': activeRelayUrl,
      }),
      metaKeyHex,
    );
    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': keyHash,
      'envelope': jsonEncode({'d': enc}),
      'content_type': kEmergencyChatContentType,
    });

    return null;
  }

  /// Fresh 32 random bytes as a hex keystream seed (never re-derived — a fresh
  /// seed per emergency chat guarantees no keystream reuse across chats).
  String _newEmergencySeed() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Replace-or-create the 1:1 [Contact] for [keyHash] as a fresh 12-hour Time
  /// Wilt chat with keystream seed [seedHex] expiring at [expiry]. Destroys any
  /// old keystream artifact and wipes previous message records (destructive
  /// recharge — no keystream reuse).
  Future<void> _applyEmergencyChat(
    String keyHash,
    String seedHex,
    DateTime expiry, {
    String? senderName,
    bool isPending = false,
    bool isInitiatorSide = false,
  }) async {
    // Preserve any received-but-unopened messages before pad reset (if applicable).
    await _preserveMessagesBeforePadReset(keyHash);
    try {
      await WiltkeyOtpService.deleteKeystreamFile(keyHash);
    } catch (e) {
      log('[EmergencyChat] Error deleting old keystream: $e');
    }

    final bool isInitiator = userId.compareTo(keyHash) < 0;
    final int stride = WiltkeyOtpService.kWiltLaneStride;
    final int outBase = isInitiator ? 0 : stride;
    final int inBase = isInitiator ? stride : 0;
    final now = DateTime.now();

    final int idx = contacts.indexWhere((c) => c.keyHash == keyHash);
    final String chatId;
    final Contact contact;

    if (idx == -1) {
      chatId = _nextContactId(isGroup: false);
      final scIdx = socialContacts.indexWhere((c) => c.keyHash == keyHash);
      final name = scIdx != -1
          ? socialContacts[scIdx].name
          : (senderName != null && senderName.isNotEmpty
              ? senderName
              : (keyHash.length >= 8 ? keyHash.substring(0, 8) : keyHash));
      contact = Contact(
        id: chatId,
        name: name,
        keyHash: keyHash,
        relayUrl: activeRelayUrl,
        isPrivateNode: _isUrlPrivate(activeRelayUrl),
        maxBufferBytes: 0,
        remainingBufferBytes: 0,
        peerRemainingBufferBytes: 0,
        lastActivity: now,
        isWilted: false,
        isArchived: false,
        isPendingEmergency: isPending,
        outgoingOffset: outBase,
        outgoingMaxOffset: outBase + stride,
        incomingOffset: inBase,
        incomingMaxOffset: inBase + stride,
        wiltExpiresAt: expiry,
        wiltCreatedAt: now,
        streamSeedHex: seedHex,
      );
      contacts.add(contact);
    } else {
      final existing = contacts[idx];
      chatId = existing.id;
      final name = (senderName != null && senderName.isNotEmpty)
          ? senderName
          : existing.name;
      contact = existing.copyWith(
        name: name,
        maxBufferBytes: 0,
        remainingBufferBytes: 0,
        peerRemainingBufferBytes: 0,
        isWilted: false,
        isArchived: false,
        isPendingEmergency: isPending,
        outgoingOffset: outBase,
        outgoingMaxOffset: outBase + stride,
        incomingOffset: inBase,
        incomingMaxOffset: inBase + stride,
        wiltExpiresAt: expiry,
        wiltCreatedAt: now,
        streamSeedHex: seedHex,
      );
      contacts[idx] = contact;
    }

    // Destructive recharge: wipe old message history for this chat
    await WiltkeyDatabase.instance.deleteMessagesForChat(chatId);

    // Initial system message
    final String note = isPending
        ? 'Emergency chat requested — waiting for contact to connect...'
        : 'Emergency chat started — this chat wilts to read-only in 12 hours.';
    final systemMsg = ChatMessage(
      id: 'emergency_${now.millisecondsSinceEpoch}',
      senderId: 'system',
      text: note,
      timestamp: now,
      isSentByMe: false,
      decryptedText: note,
    );

    messages[chatId] = [systemMsg];
    loadedChats.add(chatId);
    hasMoreOlder[chatId] = false;

    if (activeContact?.keyHash == keyHash) {
      activeContact = contact;
    }

    await WiltkeyDatabase.instance.upsertContact(contact);
    await WiltkeyDatabase.instance.saveMessage(
      systemMsg,
      chatId,
      masterKeyHex: masterKeyHex,
    );

    await _persistence.setPairingTime(
      keyHash,
      DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
    await _persistence.saveState(this);
  }

  /// Send an acknowledgment back to the peer after adopting an emergency chat.
  void _sendEmergencyChatAck(
    String recipientKeyHash,
    String seed,
    String metaKeyHex,
  ) {
    try {
      final ackPayload = jsonEncode({
        'v': 1,
        'seed': seed,
        'status': 'ready',
        'sender_name': effectiveDeviceName,
      });
      final encAck = WiltkeyPersistence().encryptString(
        ackPayload,
        metaKeyHex,
      );
      WebSocketClient().sendWSMessage({
        'type': 'SEND_MESSAGE',
        'recipient_id': recipientKeyHash,
        'envelope': jsonEncode({'d': encAck}),
        'content_type': kEmergencyChatAckContentType,
      });
    } catch (e) {
      log('[EmergencyChat] Failed to send ack: $e');
    }
  }

  /// Handle inbound `emergency_chat` — the peer created a 12-hour Time Wilt chat
  /// with us remotely. We apply the destructive replacement locally: wipe old
  /// chat messages, adopt the transmitted seed + expiry, and return an ack.
  Future<void> _handleEmergencyChat(
    String senderId,
    String envelopeStr,
  ) async {
    final metaKeyHex = await ChatMetaStore.keyFor(senderId);
    if (metaKeyHex == null) return;
    try {
      final outer = jsonDecode(envelopeStr) as Map<String, dynamic>;
      final dec = WiltkeyPersistence().decryptString(
        outer['d'] as String,
        metaKeyHex,
      );
      final p = jsonDecode(dec) as Map<String, dynamic>;
      final seed = p['seed'] as String?;
      final expiryMs = p['wilt_expires_at_ms'] as int?;
      final senderName = p['sender_name'] as String?;
      if (seed == null || seed.length != 64 || expiryMs == null) {
        log('[EmergencyChat] Invalid payload from $senderId');
        return;
      }
      final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
      final now = DateTime.now();
      if (expiry.isBefore(now)) {
        log('[EmergencyChat] Dropping expired/stale emergency chat request from $senderId');
        return;
      }

      // Guard: if we already active with the exact same seed, just re-ack
      final existingIdx = contacts.indexWhere((c) => c.keyHash == senderId);
      if (existingIdx != -1) {
        final existing = contacts[existingIdx];
        if (existing.streamSeedHex == seed &&
            !existing.isPendingEmergency &&
            existing.wiltExpiresAt != null &&
            now.isBefore(existing.wiltExpiresAt!)) {
          log('[EmergencyChat] Duplicate active emergency chat frame for $senderId; re-sending ack');
          _sendEmergencyChatAck(senderId, seed, metaKeyHex);
          return;
        }
      }

      await _applyEmergencyChat(
        senderId,
        seed,
        expiry,
        senderName: senderName,
        isPending: false,
        isInitiatorSide: false,
      );

      // Return ack so initiator unlocks their chat
      _sendEmergencyChatAck(senderId, seed, metaKeyHex);

      // A distinct "emergency chat" alert
      WiltkeyNotifications.showEmergencyChatNotification(chatKey: senderId);
    } catch (e) {
      log('[EmergencyChat Error] $e');
    }
  }

  /// Handle inbound `emergency_chat_ack` — peer created their end of the
  /// emergency chat. We clear [isPendingEmergency] so the initiator can now
  /// send and receive messages.
  Future<void> _handleEmergencyChatAck(
    String senderId,
    String envelopeStr,
  ) async {
    final metaKeyHex = await ChatMetaStore.keyFor(senderId);
    if (metaKeyHex == null) return;
    try {
      final outer = jsonDecode(envelopeStr) as Map<String, dynamic>;
      final dec = WiltkeyPersistence().decryptString(
        outer['d'] as String,
        metaKeyHex,
      );
      final p = jsonDecode(dec) as Map<String, dynamic>;
      final seed = p['seed'] as String?;
      final status = p['status'] as String?;
      if (status != 'ready' || seed == null) {
        log('[EmergencyChatAck] Invalid ack payload from $senderId');
        return;
      }

      final idx = contacts.indexWhere((c) => c.keyHash == senderId);
      if (idx == -1) return;
      final contact = contacts[idx];

      if (contact.isPendingEmergency) {
        final updated = contact.copyWith(isPendingEmergency: false);
        contacts[idx] = updated;
        if (activeContact?.keyHash == senderId) {
          activeContact = updated;
        }
        await WiltkeyDatabase.instance.upsertContact(updated);

        final now = DateTime.now();
        const note = 'Emergency chat connected — session is now active.';
        final systemMsg = ChatMessage(
          id: 'emergency_ready_${now.millisecondsSinceEpoch}',
          senderId: 'system',
          text: note,
          timestamp: now,
          isSentByMe: false,
          decryptedText: note,
        );
        final list = messages[contact.id] ?? <ChatMessage>[];
        messages[contact.id] = [...list, systemMsg];
        await WiltkeyDatabase.instance.saveMessage(
          systemMsg,
          contact.id,
          masterKeyHex: masterKeyHex,
        );

        notifyListeners();
        await _persistence.saveState(this);
        sendProfileUpdateTo(senderId);
        log('[EmergencyChatAck] Successfully unlocked emergency chat for $senderId');
      }
    } catch (e) {
      log('[EmergencyChatAck Error] $e');
    }
  }

  /// Pin or unpin a social contact (favorites float to the top of the list).
  Future<void> togglePinSocialContact(String keyHash) async {
    final idx = socialContacts.indexWhere((c) => c.keyHash == keyHash);
    if (idx == -1) return;
    final c = socialContacts[idx];
    final pinned = !c.isPinned;
    await WiltkeyDatabase.instance.updateSocialContactPinned(keyHash, pinned);
    socialContacts = [...socialContacts]
      ..removeAt(idx)
      ..insert(
        idx,
        SocialContact(
          id: c.id,
          keyHash: c.keyHash,
          name: c.name,
          shortNick: c.shortNick,
          profileImageB64: c.profileImageB64,
          avatarBorderId: c.avatarBorderId,
          themeId: c.themeId,
          sharedSecretSeed: c.sharedSecretSeed,
          myPubkey: c.myPubkey,
          peerPubkey: c.peerPubkey,
          addedAt: c.addedAt,
          isBlocked: c.isBlocked,
          themeSeed: c.themeSeed,
          lastSyncedAt: c.lastSyncedAt,
          isPinned: pinned,
          status: c.status,
        ),
      );
    _sortSocialContacts();
    notifyListeners();
  }

  /// Keep the in-memory list ordered like the DB query: pinned first, then by
  /// added time (newest first).
  void _sortSocialContacts() {
    socialContacts.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.addedAt.compareTo(a.addedAt);
    });
  }

  /// Set our own status message, optional status emoji, and expiration timestamp,
  /// persist it, and broadcast a profile_update to all contacts.
  Future<void> updateOwnStatus(
    String status, {
    String? emoji,
    int? expiresAtMs,
  }) async {
    final clean = status.trim();
    // 100-character limit enforcement
    statusMessage = clean.length > 100 ? clean.substring(0, 100) : clean;
    statusEmoji = (emoji ?? '').trim();
    statusExpiresAtMs = expiresAtMs;
    await _persistence.saveState(this);

    final notified = <String>{};
    for (final c in socialContacts) {
      notified.add(c.keyHash);
      sendProfileUpdateTo(c.keyHash);
    }
    for (final c in contacts) {
      if (!c.isGroup && !notified.contains(c.keyHash)) {
        sendProfileUpdateTo(c.keyHash);
      }
    }
    notifyListeners();
  }

  /// Clear our own status message and emoji.
  Future<void> clearOwnStatus() async {
    await updateOwnStatus('', emoji: '', expiresAtMs: null);
  }

  /// Push our current profile snapshot (name/nick/avatar/border/theme/status/statusEmoji/expiry)
  /// to a peer over the AES meta channel. Non-sensitive profile metadata.
  Future<void> sendProfileUpdateTo(String keyHash) async {
    final metaKeyHex = await ChatMetaStore.keyFor(keyHash);
    if (metaKeyHex == null) return;
    final payload = jsonEncode({
      'v': 1,
      'name': effectiveDeviceName,
      'short_nick': effectiveShortNick,
      'status': effectiveStatusMessage,
      'status_emoji': effectiveStatusEmoji,
      if (statusExpiresAtMs != null && !isOwnStatusExpired)
        'status_expires_at_ms': statusExpiresAtMs,
      'theme_id': ThemeController().themeId,
      if (profileImageB64.isNotEmpty) 'profile_image_b64': profileImageB64,
      if (equippedAvatarBorderId != null)
        'avatar_border_id': equippedAvatarBorderId,
    });
    await ensureWebSocketConnected();
    final enc = WiltkeyPersistence().encryptString(payload, metaKeyHex);
    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': keyHash,
      'envelope': jsonEncode({'d': enc}),
      'content_type': 'profile_update',
    });
  }

  /// Ask a peer for a fresh profile_update (used by the 7-day auto-refresh).
  Future<void> sendProfileUpdateRequest(String keyHash) async {
    final metaKeyHex = await ChatMetaStore.keyFor(keyHash);
    if (metaKeyHex == null) return;
    await ensureWebSocketConnected();
    final enc = WiltkeyPersistence().encryptString(
      jsonEncode({'v': 1}),
      metaKeyHex,
    );
    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': keyHash,
      'envelope': jsonEncode({'d': enc}),
      'content_type': 'profile_update_request',
    });
  }

  /// Handle inbound `profile_update` — refresh our stored snapshot of [senderId]
  /// and stamp `last_synced_at` so the 7-day clock resets.
  Future<void> _handleProfileUpdate(String senderId, String envelopeStr) async {
    final metaKeyHex = await ChatMetaStore.keyFor(senderId);
    if (metaKeyHex == null) return;
    try {
      final outer = jsonDecode(envelopeStr) as Map<String, dynamic>;
      final dec = WiltkeyPersistence().decryptString(
        outer['d'] as String,
        metaKeyHex,
      );
      final p = jsonDecode(dec) as Map<String, dynamic>;
      final now = DateTime.now().millisecondsSinceEpoch;

      final sIdx = socialContacts.indexWhere((c) => c.keyHash == senderId);
      final name = p['name'] as String? ?? (sIdx != -1 ? socialContacts[sIdx].name : null);
      final shortNick = p['short_nick'] as String?;
      final status = p['status'] as String?;
      final statusEmoji = p['status_emoji'] as String?;
      final statusExpiresAt = p['status_expires_at_ms'] as int?;
      final img = p['profile_image_b64'] as String?;
      final border = p['avatar_border_id'] as String?;
      final themeId = p['theme_id'] as String?;

      if (sIdx != -1) {
        await WiltkeyDatabase.instance.updateSocialContactProfile(
          keyHash: senderId,
          name: name,
          shortNick: shortNick,
          profileImageB64: img,
          avatarBorderId: border,
          themeId: themeId,
          status: status,
          statusEmoji: statusEmoji,
          statusExpiresAt: statusExpiresAt,
          lastSyncedAt: now,
        );
        final prev = socialContacts[sIdx];
        socialContacts = [...socialContacts]
          ..removeAt(sIdx)
          ..insert(
            sIdx,
            SocialContact(
              id: prev.id,
              keyHash: prev.keyHash,
              name: name ?? prev.name,
              shortNick: shortNick,
              profileImageB64: img,
              avatarBorderId: border,
              themeId: themeId ?? prev.themeId,
              sharedSecretSeed: prev.sharedSecretSeed,
              myPubkey: prev.myPubkey,
              peerPubkey: prev.peerPubkey,
              addedAt: prev.addedAt,
              isBlocked: prev.isBlocked,
              themeSeed: prev.themeSeed,
              lastSyncedAt: now,
              isPinned: prev.isPinned,
              status: status,
              statusEmoji: statusEmoji,
              statusExpiresAt: statusExpiresAt,
            ),
          );
      }

      // Update 1:1 Contact in chat list immediately
      final cIdx = contacts.indexWhere((c) => c.keyHash == senderId && !c.isGroup);
      if (cIdx != -1) {
        contacts[cIdx] = contacts[cIdx].copyWith(
          name: name ?? contacts[cIdx].name,
          shortNick: shortNick,
          profileImageB64: img,
          avatarBorderId: border,
          themeId: themeId,
        );
        await WiltkeyDatabase.instance.upsertContact(contacts[cIdx]);
      }

      notifyListeners();
    } catch (e) {
      log('[ProfileUpdate Error] $e');
    }
  }

  /// Handle inbound `profile_update_request` — reply with our current profile.
  Future<void> _handleProfileUpdateRequest(
    String senderId,
    String envelopeStr,
  ) async {
    final idx = socialContacts.indexWhere((c) => c.keyHash == senderId);
    if (idx == -1) return;
    final metaKeyHex = await ChatMetaStore.keyFor(senderId);
    if (metaKeyHex == null) return;
    try {
      final outer = jsonDecode(envelopeStr) as Map<String, dynamic>;
      final dec = WiltkeyPersistence().decryptString(
        outer['d'] as String,
        metaKeyHex,
      );
      jsonDecode(dec);
    } catch (_) {
      return;
    }
    await sendProfileUpdateTo(senderId);
  }

  String _newContactRequestId() {
    final u = userId.length >= 8 ? userId.substring(0, 8) : userId;
    return '${u}_contact_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _deriveSharedSecretSeed(String peerKeyHash) {
    // Derive from the two key hashes (my userId + peer's key hash), NOT the raw
    // public keys. Remote pairing can use raw pubkeys because both parties
    // exchange them at pairing time, but here we only ever know the peer's key
    // hash (sha256 of their pubkey) — so raw-pubkey derivation would produce
    // DIFFERENT results on each side (myPub vs peerHash) and every request would
    // fail the seed verification. Both sides have both hashes, so sorting the
    // pair yields an identical, deterministic seed on each end.
    final pair = [userId, peerKeyHash]..sort();
    return sha256.convert(utf8.encode(pair[0] + pair[1])).toString();
  }

  /// Insert a local system message card in a direct chat (sent by us).
  /// The card stores a plaintext JSON control payload (never OTP-encrypted):
  /// the target + current status, so it can re-render as the request resolves.
  Future<void> _insertContactRequestSentCard(
    Contact contact,
    String requestId,
    String targetKeyHash,
    String targetName,
  ) async {
    final payload = jsonEncode({
      'req_id': requestId,
      'target_key': targetKeyHash,
      'target_name': targetName,
      'status': 'pending',
    });
    final msg = ChatMessage(
      id: 'contact_req_sent_$requestId',
      senderId: 'system',
      text: payload,
      decryptedText: payload,
      contentType: 'contact_request_sent',
      timestamp: DateTime.now(),
      isSentByMe: false,
    );
    await WiltkeyDatabase.instance.saveMessage(msg, contact.id);
    appendLoadedMessage(contact.id, msg);
  }

  /// Insert a local system message card for a received contact request.
  /// Stored as a plaintext JSON control payload (never OTP-encrypted) so the
  /// Approve/Deny card can read the requester + status on rebuild.
  Future<void> _insertContactRequestReceivedCard(
    Contact contact,
    ContactRequestPayload payload,
    String senderId,
  ) async {
    final cardPayload = jsonEncode({
      'req_id': payload.requestId,
      'requester_key': senderId,
      'requester_name': payload.requesterName,
      'requester_image': payload.requesterProfileImageB64,
      'requester_border': payload.requesterAvatarBorderId,
      'status': 'pending',
    });
    final msg = ChatMessage(
      id: 'contact_req_recv_${payload.requestId}',
      senderId: 'system',
      text: cardPayload,
      decryptedText: cardPayload,
      contentType: 'contact_request_received',
      timestamp: DateTime.now(),
      isSentByMe: false,
    );
    await WiltkeyDatabase.instance.saveMessage(msg, contact.id);
    appendLoadedMessage(contact.id, msg);
  }

  /// Flip the status on a control card (sent side) in its direct chat.
  Future<void> _updateContactRequestSentCard(
    Contact contact,
    String requestId,
    String status,
  ) =>
      _updateContactRequestCardStatus(contact, 'contact_req_sent_$requestId', status);

  /// Flip the status on a control card (received side) in its direct chat.
  Future<void> _updateContactRequestReceivedCard(
    Contact contact,
    String requestId,
    String status,
  ) =>
      _updateContactRequestCardStatus(contact, 'contact_req_recv_$requestId', status);

  /// Rewrite a contact-request control card's JSON status, in memory + DB.
  Future<void> _updateContactRequestCardStatus(
    Contact contact,
    String id,
    String status,
  ) async {
    final list = messages[contact.id] ?? [];
    final idx = list.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    final msg = list[idx];
    Map<String, dynamic> p = {};
    try {
      p = jsonDecode(msg.text) as Map<String, dynamic>;
    } catch (_) {}
    p['status'] = status;
    final newText = jsonEncode(p);
    final updated = ChatMessage(
      id: msg.id,
      senderId: msg.senderId,
      text: newText,
      decryptedText: newText,
      contentType: msg.contentType,
      timestamp: msg.timestamp,
      isSentByMe: msg.isSentByMe,
    );
    final newList = [...list];
    newList[idx] = updated;
    messages[contact.id] = newList;
    await WiltkeyDatabase.instance.saveMessage(updated, contact.id);
  }
}

// Global navigator key for l10n access in background handlers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();