part of 'state.dart';

/// Shared custom-emoji pool (OTP-native).
///
/// Emojis are NOT a separate cipher channel. Each one is a one-time lane write
/// (`emoji_def` for an image, `emoji_delete` for a tombstone) — an ordinary
/// message that consumes pad bytes, full-meshes to everyone, and replays via
/// resync, exactly like text/images. On author/receipt/resync we PIN the
/// payload into CustomEmojiStore (union-merge, newer createdAtMs wins) instead
/// of rendering it as a chat bubble. See defineEmoji / deleteChatEmoji and the
/// emoji_def/emoji_delete branches in the receive + resync paths.
extension AppStateEmoji on AppState {
  /// Author a custom emoji: write it once into our own lane (`emoji_def`) so it
  /// costs real keystream and reaches everyone via the normal send path, then
  /// pin it locally (full-mesh excludes self, so our own def never echoes back).
  /// Returns null on success or an error string from the send path.
  Future<String?> defineEmoji(Contact contact, CustomEmoji emoji) async {
    final payload = jsonEncode(emoji.toJson());
    final prevActive = activeContact;
    activeContact =
        contact; // sendMessage / sendGroupMessage target activeContact
    String? err;
    try {
      err = contact.isGroup
          ? await sendGroupMessage(payload, contentType: 'emoji_def')
          : await sendMessage(payload, contentType: 'emoji_def');
    } finally {
      if (prevActive != null) activeContact = prevActive;
    }
    if (err != null) return err;
    final budget = contact.isGroup
        ? AppState.infoLaneSize
        : ChatMetaStore.budgetFor(contact.maxBufferBytes);
    await CustomEmojiStore.add(contact.keyHash, emoji, maxBytes: budget);
    notifyListeners();
    return null;
  }

  /// Delete a custom emoji: write a tiny `emoji_delete` tombstone into our lane
  /// (the spent image bytes are unreclaimable) and tombstone it locally.
  Future<String?> deleteChatEmoji(Contact contact, String name) async {
    final existing = CustomEmojiStore.cachedMap(contact.keyHash)[name];
    final reserved = existing?.approxBytes ?? 0;
    final payload = jsonEncode({
      'name': name,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'deleted': true,
      'rb': reserved,
    });
    final prevActive = activeContact;
    activeContact = contact;
    String? err;
    try {
      err = contact.isGroup
          ? await sendGroupMessage(payload, contentType: 'emoji_delete')
          : await sendMessage(payload, contentType: 'emoji_delete');
    } finally {
      if (prevActive != null) activeContact = prevActive;
    }
    if (err != null) return err;
    await CustomEmojiStore.tombstone(contact.keyHash, name);
    notifyListeners();
    return null;
  }

  /// Pin an inbound emoji control payload (`emoji_def` or `emoji_delete`) into
  /// the shared pool. Idempotent + order-independent via mergeAll (newer ts wins,
  /// so a delete overrides its def regardless of arrival order).
  Future<void> _pinEmojiPayload(
    String chatKey,
    String decryptedJson,
    int maxBytes,
  ) async {
    try {
      final m = jsonDecode(decryptedJson) as Map<String, dynamic>;
      final emoji = CustomEmoji.fromJson(m);
      await CustomEmojiStore.mergeAll(chatKey, [emoji], maxBytes: maxBytes);
    } catch (e) {
      log('[Emoji Error] Failed to pin emoji payload: $e');
    }
  }
}
