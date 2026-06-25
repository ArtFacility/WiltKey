import 'package:shared_preferences/shared_preferences.dart';

/// Per-peer metadata key store + the "relative metadata budget" rules for 1-on-1
/// chats.
///
/// We do NOT persist the pairwise pad seed (that would let a seized device
/// regenerate already-consumed keystream and break forward secrecy). Instead, at
/// enrol time both sides derive a ONE-WAY metadata key — `SHA256(seed + ":meta")`
/// — and store only that. It encrypts the `chat_info_update` channel (profiles,
/// permissions, later emojis) but can't reconstruct the message keystream.
class ChatMetaStore {
  ChatMetaStore._();

  static const String _prefix = 'wk_chatmeta_';
  static final Map<String, String> _cache = {};

  static String _k(String keyHash) => '$_prefix$keyHash';

  /// Store the derived metadata key (hex) for a peer.
  static Future<void> setKey(String keyHash, String metaKeyHex) async {
    _cache[keyHash] = metaKeyHex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_k(keyHash), metaKeyHex);
  }

  /// Return the peer's metadata key (hex), loading from disk if needed.
  /// Null if this contact predates the feature (re-pair to provision one).
  static Future<String?> keyFor(String keyHash) async {
    final cached = _cache[keyHash];
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_k(keyHash));
    if (v != null) _cache[keyHash] = v;
    return v;
  }

  static Future<void> clear(String keyHash) async {
    _cache.remove(keyHash);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_k(keyHash));
  }

  // --- Relative metadata budget ---------------------------------------------
  // The metadata "size" is not a hard reservation in the pad (that would be
  // silly for a 100 KB chat); it's a soft, pad-relative budget that gates
  // features and bounds how much profile/emoji data a chat syncs.

  static const double _ratio = 0.02; // ~2% of the pad
  static const int _budgetCap = 1024 * 1024; // never more than 1 MB
  static const int customEmojiThreshold =
      50 * 1024; // emojis need ≥ ~50 KB budget

  /// Soft metadata budget in bytes for a chat of [bufferBytes] total pad.
  /// e.g. 100 KB → ~2 KB (no emojis); 5 MB → ~100 KB; 50 MB → 1 MB (capped).
  static int budgetFor(int bufferBytes) {
    final b = (bufferBytes * _ratio).round();
    return b < 0 ? 0 : (b > _budgetCap ? _budgetCap : b);
  }

  /// Whether a chat of this size is large enough to support custom emojis.
  static bool customEmojisAllowed(int bufferBytes) =>
      budgetFor(bufferBytes) >= customEmojiThreshold;
}
