part of 'state.dart';

/// 1-on-1 metadata channel: AES-encrypted profile/permission + archive
/// signalling keyed by the peer's one-way metadata key (ChatMetaStore),
/// mirroring the group group_info_update. Independent of the OTP pad.
extension AppStateChatMeta on AppState {
  // --- 1-on-1 metadata channel (profile + permissions sync) ------------------
  // Mirrors the group `group_info_update`: an AES-encrypted relay message keyed
  // by the peer's one-way metadata key (ChatMetaStore). Lets avatar/name/nick
  // and the image permission propagate AFTER pairing — something the old
  // BLE-only profile exchange never did. Nothing here touches the OTP pad or
  // the BLE handshake.

  /// Push our current profile + the chat's image permission to a 1-on-1 peer.
  Future<void> sendChatInfoUpdate(Contact contact) async {
    if (contact.isGroup) return;
    final metaKeyHex = await ChatMetaStore.keyFor(contact.keyHash);
    if (metaKeyHex == null)
      return; // contact predates the feature; re-pair to enable
    await ensureWebSocketConnected();
    final payload = jsonEncode({
      'name': effectiveDeviceName,
      'short_nick': effectiveShortNick,
      'profile_image': profileImageB64,
      'images_allowed': contact.imagesAllowed ?? true,
      'relay_url': activeRelayUrl, // advertise our relay for peer fallback
      'v': 1,
    });
    final enc = WiltkeyPersistence().encryptString(payload, metaKeyHex);
    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': contact.keyHash,
      'envelope': jsonEncode({'d': enc}),
      'content_type': 'chat_info_update',
    });
  }

  /// Tell a 1-on-1 peer we've archived (gone read-only) so their side can wilt
  /// early — a "soft nuke" that, unlike a real nuke, leaves their history intact.
  /// Rides the metadata channel, so it works even though our pad is being dropped.
  Future<void> sendArchiveSignal(Contact contact) async {
    if (contact.isGroup) return;
    final metaKeyHex = await ChatMetaStore.keyFor(contact.keyHash);
    if (metaKeyHex == null) return; // contact predates the metadata channel
    await ensureWebSocketConnected();
    final payload = jsonEncode({'archived': true, 'v': 1});
    final enc = WiltkeyPersistence().encryptString(payload, metaKeyHex);
    WebSocketClient().sendWSMessage({
      'type': 'SEND_MESSAGE',
      'recipient_id': contact.keyHash,
      'envelope': jsonEncode({'d': enc}),
      'content_type': 'archive_signal',
    });
  }

  /// Apply an incoming peer archive signal: flag a premature wilt and telegraph
  /// it in the chat so the user understands why the chat suddenly went inert.
  Future<void> _handleArchiveSignal(String senderId, String envelopeStr) async {
    final idx = contacts.indexWhere((c) => c.keyHash == senderId);
    if (idx == -1) return;
    final contact = contacts[idx];
    if (contact.isGroup || contact.isArchived) return;
    final metaKeyHex = await ChatMetaStore.keyFor(senderId);
    if (metaKeyHex == null) return;
    try {
      final outer = jsonDecode(envelopeStr) as Map<String, dynamic>;
      final dec = WiltkeyPersistence().decryptString(
        outer['d'] as String,
        metaKeyHex,
      );
      final p = jsonDecode(dec) as Map<String, dynamic>;
      if (p['archived'] != true) return;
      if (contact.isWilted) return; // already wilted — nothing to telegraph
      final updated = contact.copyWith(isWilted: true);
      contacts[idx] = updated;
      if (activeContact?.keyHash == senderId) activeContact = updated;
      await WiltkeyDatabase.instance.upsertContact(updated);
      await addSystemMessage(
        updated,
        '${updated.name} archived this chat on their end — it has wilted early, and new messages won\'t reach them.',
      );
      notifyListeners();
      _persistence.saveState(this);
      log('[Archive] Peer ${updated.name} archived; flagged premature wilt.');
    } catch (e) {
      log('[Archive Signal Error] $e');
    }
  }

  /// Push our profile/permissions to every 1-on-1 peer (on connect / profile edit).
  void broadcastChatInfoToPeers() {
    for (final c in contacts) {
      if (!c.isGroup) sendChatInfoUpdate(c);
    }
  }

  /// Toggle the (mutual) image permission for a 1-on-1 chat and sync it to the peer.
  Future<void> setChatImagesAllowed(Contact contact, bool allowed) async {
    final idx = contacts.indexWhere((c) => c.keyHash == contact.keyHash);
    if (idx == -1) return;
    final updated = contacts[idx].copyWith(imagesAllowed: allowed);
    contacts[idx] = updated;
    if (activeContact?.keyHash == contact.keyHash) activeContact = updated;
    await WiltkeyDatabase.instance.upsertContact(updated);
    notifyListeners();
    _persistence.saveState(this);
    await sendChatInfoUpdate(updated);
  }

  /// Apply an incoming peer profile/permission update (merge — never overwrite
  /// good values with blanks).
  Future<void> _handleChatInfoUpdate(
    String senderId,
    String envelopeStr,
  ) async {
    final idx = contacts.indexWhere((c) => c.keyHash == senderId);
    if (idx == -1) return;
    final contact = contacts[idx];
    if (contact.isGroup) return;
    final metaKeyHex = await ChatMetaStore.keyFor(senderId);
    if (metaKeyHex == null) return;
    try {
      final outer = jsonDecode(envelopeStr) as Map<String, dynamic>;
      final dec = WiltkeyPersistence().decryptString(
        outer['d'] as String,
        metaKeyHex,
      );
      final p = jsonDecode(dec) as Map<String, dynamic>;

      final name = (p['name'] as String?)?.trim();
      final nick = (p['short_nick'] as String?)?.trim();
      final img = (p['profile_image'] as String?)?.trim();
      final imagesAllowed = p['images_allowed'] as bool?;

      // Remember the peer's relay as a connection fallback (filtered + persisted).
      addKnownPeerRelay(p['relay_url'] as String?);

      final updated = contact.copyWith(
        name: (name != null && name.isNotEmpty) ? name : null,
        shortNick: (nick != null && nick.isNotEmpty) ? nick : null,
        profileImageB64: (img != null && img.isNotEmpty) ? img : null,
        imagesAllowed: imagesAllowed,
      );
      contacts[idx] = updated;
      if (activeContact?.keyHash == senderId) activeContact = updated;
      await WiltkeyDatabase.instance.upsertContact(updated);
      notifyListeners();
      _persistence.saveState(this);
      log('[ChatInfo] Applied profile/permission update from ${updated.name}');
    } catch (e) {
      log('[ChatInfo Error] $e');
    }
  }
}
