import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A user-created custom emoji, invoked in messages via the Discord-like
/// `:name:` format. Images are stored as base64-encoded WebP bytes.
///
/// Emojis form a **shared pool per chat**, keyed by the stable `keyHash` (so a
/// recharge keeps them) and synced to the peer/group over the existing AES
/// metadata channels — see `documentation/groupchat_implementation.md`.
///
/// **Deletion is a tombstone, not a removal.** Because the OTP/metadata budget
/// can't be reclaimed once spent, deleting drops the image bytes but keeps a
/// dead slot ([deleted] = true) that still costs [reservedBytes] against the
/// budget. The tombstone's [createdAtMs] is bumped to delete-time so it wins the
/// union-merge and the deletion propagates to the rest of the chat.
class CustomEmoji {
  /// The token name WITHOUT the surrounding colons, e.g. `partyparrot`.
  final String name;

  /// Base64-encoded WebP bytes of the cropped emoji image (empty when deleted).
  final String imageB64;

  /// Creation time (unix millis); bumped to delete-time on tombstoning.
  final int createdAtMs;

  /// Whether this is a tombstone (deleted emoji whose budget stays burned).
  final bool deleted;

  /// The budget cost frozen at delete-time (the live image's size). For live
  /// emojis this is ignored; [approxBytes] uses the live image length instead.
  final int reservedBytes;

  const CustomEmoji({
    required this.name,
    required this.imageB64,
    required this.createdAtMs,
    this.deleted = false,
    this.reservedBytes = 0,
  });

  /// The displayable token, e.g. `:partyparrot:`.
  String get token => ':$name:';

  /// Approximate stored size in bytes. Live: the base64 image length. Tombstone:
  /// the frozen [reservedBytes] (a dead slot keeps costing budget — "junk data").
  int get approxBytes => deleted ? reservedBytes : imageB64.length;

  Uint8List get bytes => base64Decode(imageB64);

  /// Returns the tombstone form of this emoji: image bytes dropped, budget cost
  /// frozen, timestamp bumped to [nowMs] so it wins the union-merge.
  CustomEmoji toTombstone(int nowMs) => CustomEmoji(
    name: name,
    imageB64: '',
    createdAtMs: nowMs,
    deleted: true,
    reservedBytes: deleted ? reservedBytes : imageB64.length,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'img': imageB64,
    'ts': createdAtMs,
    if (deleted) 'deleted': true,
    if (deleted) 'rb': reservedBytes,
  };

  factory CustomEmoji.fromJson(Map<String, dynamic> json) {
    final img = (json['img'] as String?) ?? '';
    final isDeleted = (json['deleted'] as bool?) ?? false;
    return CustomEmoji(
      name: json['name'] as String,
      imageB64: img,
      createdAtMs: (json['ts'] as int?) ?? 0,
      deleted: isDeleted,
      // Back-compat: pre-tombstone records have no `rb`; fall back to image size.
      reservedBytes: (json['rb'] as int?) ?? img.length,
    );
  }

  /// Emoji names must be lowercase alphanumeric/underscore, 2-32 chars — this
  /// keeps the `:name:` token unambiguous to parse.
  static final RegExp nameRule = RegExp(r'^[a-z0-9_]{2,32}$');

  static bool isValidName(String name) => nameRule.hasMatch(name);
}

/// Per-chat store for custom emojis, backed by SharedPreferences and keyed by
/// the chat's stable `keyHash` (1-on-1 contact or group), so emojis survive a
/// recharge. Maintains an in-memory cache so message rendering can resolve
/// `:name:` tokens synchronously.
///
/// The list holds both live emojis and tombstones (deleted slots). Rendering and
/// autocomplete read [cachedMap] (live only); the management grid and budget read
/// [cached] / [totalBytes] (tombstones included).
class CustomEmojiStore {
  CustomEmojiStore._();

  static const String _prefix = 'wk_emojis_';

  // chatKey (keyHash) -> list of emojis (live + tombstones)
  static final Map<String, List<CustomEmoji>> _cache = {};

  static String _key(String chatKey) => '$_prefix$chatKey';

  /// Returns the cached list including tombstones (for the management grid).
  static List<CustomEmoji> cached(String chatKey) =>
      List.unmodifiable(_cache[chatKey] ?? const []);

  /// Builds a name->emoji lookup of **live** emojis for inline rendering and
  /// autocomplete (tombstones excluded).
  static Map<String, CustomEmoji> cachedMap(String chatKey) {
    return {
      for (final e in (_cache[chatKey] ?? const []))
        if (!e.deleted) e.name: e,
    };
  }

  /// Total budget cost of the pool: live image bytes + tombstone reservedBytes.
  static int totalBytes(String chatKey) {
    int sum = 0;
    for (final e in (_cache[chatKey] ?? const <CustomEmoji>[])) {
      sum += e.approxBytes;
    }
    return sum;
  }

  /// Loads emojis for a chat from disk into the cache and returns them.
  static Future<List<CustomEmoji>> load(String chatKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(chatKey));
    if (raw == null || raw.isEmpty) {
      _cache[chatKey] = [];
      return const [];
    }
    try {
      final List<dynamic> arr = jsonDecode(raw) as List<dynamic>;
      final list = arr
          .map((e) => CustomEmoji.fromJson(e as Map<String, dynamic>))
          .toList();
      _cache[chatKey] = list;
      return list;
    } catch (_) {
      _cache[chatKey] = [];
      return const [];
    }
  }

  static Future<void> _persist(String chatKey) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _cache[chatKey] ?? [];
    await prefs.setString(
      _key(chatKey),
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  /// Adds (or replaces by name) an emoji and persists. Returns false if the
  /// name is invalid, or if [maxBytes] is given and the pool (including
  /// tombstones) would exceed it.
  static Future<bool> add(
    String chatKey,
    CustomEmoji emoji, {
    int? maxBytes,
  }) async {
    if (!CustomEmoji.isValidName(emoji.name)) return false;
    final list = _cache[chatKey] ?? (await load(chatKey)).toList();
    if (maxBytes != null) {
      int other = 0;
      for (final e in list) {
        if (e.name != emoji.name) other += e.approxBytes;
      }
      if (other + emoji.approxBytes > maxBytes) return false;
    }
    final mutable = List<CustomEmoji>.from(list)
      ..removeWhere((e) => e.name == emoji.name)
      ..add(emoji);
    _cache[chatKey] = mutable;
    await _persist(chatKey);
    return true;
  }

  /// Tombstones a live emoji by name: drops its image bytes but keeps a dead
  /// slot whose budget cost stays burned, timestamp bumped so the deletion wins
  /// the union-merge and propagates to the chat. No-op if not found/already dead.
  static Future<void> tombstone(String chatKey, String name) async {
    final list = _cache[chatKey] ?? (await load(chatKey)).toList();
    final idx = list.indexWhere((e) => e.name == name && !e.deleted);
    if (idx < 0) return;
    final mutable = List<CustomEmoji>.from(list);
    mutable[idx] = mutable[idx].toTombstone(
      DateTime.now().millisecondsSinceEpoch,
    );
    _cache[chatKey] = mutable;
    await _persist(chatKey);
  }

  /// Union-merges [incoming] into the chat's pool: for each name, the entry with
  /// the newer [CustomEmoji.createdAtMs] wins (so an incoming tombstone can
  /// overwrite a local live emoji and vice-versa). If [maxBytes] is given, trims
  /// the oldest entries until the pool fits. Persists + updates the cache.
  /// Returns true if anything was added or changed (drives group host re-broadcast).
  static Future<bool> mergeAll(
    String chatKey,
    List<CustomEmoji> incoming, {
    int? maxBytes,
  }) async {
    final list = _cache[chatKey] ?? (await load(chatKey)).toList();
    final byName = {for (final e in list) e.name: e};
    bool changed = false;
    for (final inc in incoming) {
      if (!CustomEmoji.isValidName(inc.name)) continue;
      final existing = byName[inc.name];
      if (existing == null || inc.createdAtMs > existing.createdAtMs) {
        byName[inc.name] = inc;
        changed = true;
      }
    }
    if (!changed) return false;

    var merged = byName.values.toList()
      ..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    if (maxBytes != null) {
      int total = merged.fold(0, (s, e) => s + e.approxBytes);
      while (total > maxBytes && merged.isNotEmpty) {
        total -= merged.first.approxBytes;
        merged.removeAt(0);
      }
    }
    _cache[chatKey] = merged;
    await _persist(chatKey);
    return true;
  }

  static Future<void> remove(String chatKey, String name) async {
    final list = _cache[chatKey];
    if (list == null) return;
    list.removeWhere((e) => e.name == name);
    await _persist(chatKey);
  }

  /// Whether a **live** emoji with this name exists (tombstoned names are free
  /// to reuse).
  static bool nameExists(String chatKey, String name) =>
      (_cache[chatKey] ?? const []).any((e) => e.name == name && !e.deleted);

  /// Clears a chat's emojis from cache + disk (used on leave/nuke).
  static Future<void> clear(String chatKey) async {
    _cache.remove(chatKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(chatKey));
  }
}

// --- Stickers ----------------------------------------------------------------
// A "sticker" is an ordinary message whose body is a single emoji (unicode) or
// custom `:name:` token, sent for big, bubble-less display. It rides the normal
// text path — no new content_type and no extra OTP/keystream budget — and is
// distinguished only by a control-character sentinel that can't appear in
// user-typed text, so it survives encryption, delivery, and resync untouched.
const String kStickerMarker = 'stk';

/// Wraps an emoji / `:name:` token as a sticker message body.
String wrapSticker(String payload) => '$kStickerMarker$payload';

/// The sticker payload if [text] is a sticker body, otherwise null.
String? stickerPayload(String text) => text.startsWith(kStickerMarker)
    ? text.substring(kStickerMarker.length)
    : null;

/// Human-readable form for previews/notifications: the bare emoji/token with the
/// sentinel stripped (so the control chars never leak into a chat-list subtitle).
String stripStickerMarker(String text) => stickerPayload(text) ?? text;

// --- Jumbo-emoji detection ---------------------------------------------------
// Messengers render an emoji-only message at a larger size ("jumbo"). We treat
// a message as jumbo when, after removing whitespace and resolved custom
// `:name:` tokens, every remaining character is a unicode emoji (base glyph or
// modifier) and the total cluster count is small. Mixed text+emoji stays normal.

final RegExp _customTokenRule = RegExp(r':([a-z0-9_]{2,32}):');

bool _isJumboWhitespace(int c) =>
    c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

// ZWJ, variation selectors, combining keycap and skin-tone modifiers: part of an
// emoji but not a standalone cluster.
bool _isEmojiModifier(int c) =>
    c == 0x200D ||
    c == 0xFE0F ||
    c == 0xFE0E ||
    c == 0x20E3 ||
    (c >= 0x1F3FB && c <= 0x1F3FF);

// Standalone emoji glyph ranges (the common, clearly-pictographic blocks). Kept
// deliberately conservative so ordinary symbol text isn't mistaken for emoji.
bool _isEmojiBase(int c) =>
    (c >= 0x1F300 &&
        c <= 0x1FAFF) || // pictographs, emoticons, transport, supplemental
    (c >= 0x1F000 && c <= 0x1F0FF) || // mahjong / dominoes / playing cards
    (c >= 0x1F1E6 && c <= 0x1F1FF) || // regional indicators (flags)
    (c >= 0x2600 && c <= 0x27BF) || // misc symbols + dingbats
    (c >= 0x2B00 && c <= 0x2BFF) || // misc symbols & arrows (stars, etc.)
    (c >= 0x2300 && c <= 0x23FF); // misc technical (⌚ ⏰ ⏳ …)

/// Returns the emoji cluster count when [text] is emoji-only and short enough to
/// render large, otherwise null (render at normal size). Custom `:name:` tokens
/// that resolve in [emojiMap] count as one cluster each; unresolved tokens are
/// plain text and disqualify the message.
int? jumboEmojiCount(String text, Map<String, CustomEmoji> emojiMap) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  int clusters = 0;
  final withoutCustom = trimmed.replaceAllMapped(_customTokenRule, (m) {
    if (emojiMap.containsKey(m.group(1))) {
      clusters++;
      return ' '; // replace with whitespace so it's skipped below
    }
    return m.group(0)!; // unresolved -> stays as text, fails the emoji check
  });

  for (final c in withoutCustom.runes) {
    if (_isJumboWhitespace(c) || _isEmojiModifier(c)) continue;
    if (_isEmojiBase(c)) {
      clusters++;
      continue;
    }
    return null; // a non-emoji, non-space character: not emoji-only
  }

  if (clusters == 0 || clusters > 8) return null;
  return clusters;
}

/// Renders text with inline custom emojis. Any `:name:` token that resolves to
/// a known emoji in [emojiMap] is drawn as a small inline image; everything
/// else renders as normal text in [style].
class EmojiText extends StatelessWidget {
  final String text;
  final Map<String, CustomEmoji> emojiMap;
  final TextStyle style;
  final double emojiSize;

  const EmojiText({
    super.key,
    required this.text,
    required this.emojiMap,
    required this.style,
    this.emojiSize = 20,
  });

  static final RegExp _tokenRule = RegExp(r':([a-z0-9_]{2,32}):');

  @override
  Widget build(BuildContext context) {
    if (emojiMap.isEmpty || !text.contains(':')) {
      return Text(text, style: style);
    }

    final List<InlineSpan> spans = [];
    int last = 0;
    for (final match in _tokenRule.allMatches(text)) {
      final name = match.group(1)!;
      final emoji = emojiMap[name];
      if (emoji == null) continue; // leave unknown tokens as plain text

      if (match.start > last) {
        spans.add(
          TextSpan(text: text.substring(last, match.start), style: style),
        );
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.0),
            child: Image.memory(
              emoji.bytes,
              width: emojiSize,
              height: emojiSize,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => Text(emoji.token, style: style),
            ),
          ),
        ),
      );
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: style));
    }
    if (spans.isEmpty) return Text(text, style: style);

    return Text.rich(TextSpan(children: spans), style: style);
  }
}
