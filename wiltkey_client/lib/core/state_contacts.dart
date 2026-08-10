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
  /// Load social contacts from DB into memory. Called on startup.
  Future<void> loadSocialContacts() async {
    try {
      final rows = await WiltkeyDatabase.instance.getAllSocialContacts();
      socialContacts = rows;
      notifyListeners();
    } catch (e) {
      log('[Contacts] load failed: $e');
    }
  }

  /// Send a contact request to an existing 1-on-1 chat peer.
  /// The request is sent over the AES meta channel (not the OTP pad).
  /// [sentText] and [receivedText] should be pre-localized by the caller (UI).
  Future<String?> sendContactRequest(
    Contact contact, {
    required String sentText,
    required String receivedText,
  }) async {
    if (contact.isGroup) {
      return 'Contact requests only work for 1-on-1 chats';
    }
    if (contact.keyHash == userId) {
      return 'You cannot add yourself';
    }
    // Check if already a social contact
    if (socialContacts.any((c) => c.keyHash == contact.keyHash)) {
      return 'Already in your contacts';
    }
    // Check if blocked locally
    if (await WiltkeyDatabase.instance.isContactBlocked(contact.keyHash)) {
      return 'This user is blocked';
    }

    final metaKeyHex = await ChatMetaStore.keyFor(contact.keyHash);
    if (metaKeyHex == null) {
      return 'This chat predates the metadata channel — re-pair to enable contact requests';
    }

    final requestId = _newContactRequestId();
    final sharedSecretSeed = _deriveSharedSecretSeed(contact.keyHash);

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
      'recipient_id': contact.keyHash,
      'envelope': jsonEncode({'d': enc}),
      'content_type': 'contact_request',
    });

    // Track pending request for UI
    _pendingContactRequests[requestId] = PendingContactRequest(
      requestId: requestId,
      targetKeyHash: contact.keyHash,
      targetName: contact.name,
      sentAt: DateTime.now(),
    );

    // Insert a local system message card in the chat (sent by us)
    await _insertContactRequestSentCard(contact, requestId, sentText);

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
      final receivedText = 'Contact request received from ${payload.requesterName}';
      await _insertContactRequestReceivedCard(contact, payload, receivedText);
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
          );
          await WiltkeyDatabase.instance.insertSocialContact(sc);
          socialContacts.insert(0, sc);
        }
        pending.status = 'accepted';
      } else {
        pending.status = 'declined';
      }

      // Update the local sent card
      await _updateContactRequestSentCard(pending);
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
          peerPubkey: contact.keyHash, // We'll update this when we get their response
          addedAt: DateTime.now().millisecondsSinceEpoch,
          isBlocked: false,
        );
        await WiltkeyDatabase.instance.insertSocialContact(sc);
        socialContacts.insert(0, sc);
      }
      // Update the received card to "accepted"
      await _updateContactRequestReceivedCard(contact, requestId, 'accepted');
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

  /// Block a peer — adds to local block list and removes from contacts if present.
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
    notifyListeners();
  }

  /// Unblock a peer.
  Future<void> unblockContact(String keyHash) async {
    await WiltkeyDatabase.instance.deleteContactBlock(keyHash);
    notifyListeners();
  }

  String _newContactRequestId() {
    final u = userId.length >= 8 ? userId.substring(0, 8) : userId;
    return '${u}_contact_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _deriveSharedSecretSeed(String peerKeyHash) {
    // Same derivation as remote pairing: sha256(sorted(myPub + peerPub))
    final pair = [publicKeyHex, peerKeyHash]..sort();
    return sha256.convert(utf8.encode(pair[0] + pair[1])).toString();
  }

  /// Insert a local system message card in the chat (sent by us).
  /// [text] should be pre-localized by the caller.
  Future<void> _insertContactRequestSentCard(
    Contact contact,
    String requestId,
    String text,
  ) async {
    final msg = ChatMessage(
      id: 'contact_req_sent_$requestId',
      senderId: 'system',
      text: text,
      contentType: 'contact_request_sent',
      timestamp: DateTime.now(),
      isSentByMe: false,
    );
    await WiltkeyDatabase.instance.saveMessage(msg, contact.id, masterKeyHex: masterKeyHex);
    appendLoadedMessage(contact.id, msg);
  }

  /// Insert a local system message card for a received contact request.
  /// [text] should be pre-localized by the caller.
  Future<void> _insertContactRequestReceivedCard(
    Contact contact,
    ContactRequestPayload payload,
    String text,
  ) async {
    final msg = ChatMessage(
      id: 'contact_req_recv_${payload.requestId}',
      senderId: 'system',
      text: text,
      contentType: 'contact_request_received',
      timestamp: DateTime.now(),
      isSentByMe: false,
    );
    await WiltkeyDatabase.instance.saveMessage(msg, contact.id, masterKeyHex: masterKeyHex);
    appendLoadedMessage(contact.id, msg);
  }

  Future<void> _updateContactRequestSentCard(PendingContactRequest pending) async {
    // Find and update the message in the chat
    // For now, the UI will reflect the status via the pending map
  }

  Future<void> _updateContactRequestReceivedCard(
    Contact contact,
    String requestId,
    String status,
  ) async {
    // Similar to above
  }
}

// Global navigator key for l10n access in background handlers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();