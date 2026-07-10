part of 'state.dart';

/// Emoji reactions on messages. Rides the **AES metadata channel** (the same
/// control-frame transport as delivery-check / profile sync), NOT the OTP pad —
/// a reaction spends no keystream. A frame references a target message by its
/// (cross-peer stable) [ChatMessage.id] plus an emoji token and add/remove op.
///
/// Best-effort by design: frames sit in the relay's 24h store-and-forward like
/// any message, and a missed reaction is acceptable loss. Reactions are mutable
/// side-metadata — receiving one edits an already-persisted message in place
/// (DB `reactions` column) and rebuilds its bubble.
extension AppStateReactions on AppState {
  /// Toggle the local user's [token] reaction on [msg] in [contact]'s chat:
  /// applies locally (optimistic), persists, and sends the frame to the peer(s).
  Future<void> toggleReaction(
    Contact contact,
    ChatMessage msg,
    String token,
  ) async {
    if (msg.isSystem) return;
    final add = !(msg.reactions[token]?.contains(userId) ?? false);
    await _applyReaction(
      contact: contact,
      targetId: msg.id,
      token: token,
      reactorId: userId,
      add: add,
    );
    await _sendReactionFrame(contact, msg.id, token, add);
  }

  /// Applies a reaction change to both the DB (authoritative) and the in-memory
  /// message window (if the target is loaded), then rebuilds. No-op if the target
  /// message isn't stored (a reaction can outrun its message).
  Future<void> _applyReaction({
    required Contact contact,
    required String targetId,
    required String token,
    required String reactorId,
    required bool add,
  }) async {
    final updated = await WiltkeyDatabase.instance.mutateMessageReaction(
      targetId,
      token: token,
      reactorId: reactorId,
      add: add,
    );
    if (updated == null) return; // target not stored — drop (best-effort)

    final list = messages[contact.id];
    if (list != null) {
      for (final m in list) {
        if (m.id == targetId) {
          m.reactions = updated;
          break;
        }
      }
    }
    notifyListeners();
  }

  /// Sends a reaction frame — 1-on-1 over the peer's metadata key, group as a
  /// full-mesh `group_reaction` keyed by SHA256(groupSeed).
  Future<void> _sendReactionFrame(
    Contact contact,
    String targetId,
    String token,
    bool add,
  ) async {
    final payload = jsonEncode({
      'target_id': targetId,
      'emoji': token,
      'op': add ? 'add' : 'remove',
      'v': 1,
    });

    if (contact.isGroup) {
      final seed = contact.groupSeed ?? '';
      if (seed.isEmpty) return;
      final keyHex = sha256.convert(utf8.encode(seed)).toString();
      final enc = WiltkeyPersistence().encryptString(payload, keyHex);
      final envelope = jsonEncode({
        'group_id': contact.keyHash,
        'sender_id': userId,
        'd': enc,
        't': 'group_reaction',
      });
      await ensureWebSocketConnected();
      for (final memberHash in contact.memberKeyHashes) {
        if (memberHash == userId) continue;
        WebSocketClient().sendWSMessage({
          'type': 'SEND_MESSAGE',
          'recipient_id': memberHash,
          'envelope': envelope,
          'content_type': 'group_reaction',
        });
      }
    } else {
      final metaKeyHex = await ChatMetaStore.keyFor(contact.keyHash);
      if (metaKeyHex == null) return; // contact predates the metadata channel
      await ensureWebSocketConnected();
      final enc = WiltkeyPersistence().encryptString(payload, metaKeyHex);
      WebSocketClient().sendWSMessage({
        'type': 'SEND_MESSAGE',
        'recipient_id': contact.keyHash,
        'envelope': jsonEncode({'d': enc}),
        'content_type': 'reaction',
      });
    }
  }

  /// Handle an inbound 1-on-1 `reaction` frame (metadata-key encrypted).
  Future<void> _handleReaction(String senderId, String envelopeStr) async {
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
      await _applyReactionFromPayload(contact, senderId, p);
    } catch (e) {
      log('[Reaction Error] $e');
    }
  }

  /// Handle an inbound group `group_reaction` frame (SHA256(seed) encrypted).
  Future<void> _handleGroupReaction(
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
      await _applyReactionFromPayload(group, senderId, p);
    } catch (e) {
      log('[Group Reaction Error] $e');
    }
  }

  Future<void> _applyReactionFromPayload(
    Contact contact,
    String reactorId,
    Map<String, dynamic> p,
  ) async {
    final targetId = p['target_id'] as String?;
    final token = p['emoji'] as String?;
    if (targetId == null || token == null || token.isEmpty) return;
    final add = (p['op'] as String?) != 'remove';
    await _applyReaction(
      contact: contact,
      targetId: targetId,
      token: token,
      reactorId: reactorId,
      add: add,
    );
  }
}
