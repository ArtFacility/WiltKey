import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Central pixel-art format + palette registry for WiltKey avatars, group icons
/// and identicons.
///
/// ## The format
/// A pixel grid is always 10x10 = 100 cells. Each cell holds a palette *index*.
/// Two on-the-wire / on-disk encodings are supported:
///
///  * **Legacy hex** — exactly 100 hex chars (`[0-9a-fA-F]`), one nibble per
///    cell → indices 0–15 only. This is the original format.
///  * **v2** — `"v2:" + base64(100 bytes)`, one byte per cell → indices 0–255.
///
/// [PixelGrid.encode] is *adaptive*: it emits the legacy hex form whenever every
/// index fits in 0–15, and only switches to `v2:` once a cell actually uses a
/// colour at index >= 16. That means all existing art (and any new art drawn
/// with the classic 16 colours) stays in the universally-readable legacy form —
/// clients that predate this change keep rendering it correctly. A `v2:` string
/// only appears when a genuinely new colour is used, and older clients then fall
/// back gracefully (unknown index → background) instead of crashing.
///
/// Because of this there is **no eager migration step**: stored legacy grids are
/// already canonical and render unchanged.
class PixelGrid {
  PixelGrid._();

  static const int dim = 10;
  static const int cells = dim * dim; // 100
  static const String _v2Prefix = 'v2:';

  /// Parse either encoding into a list of [cells] palette indices (0–255).
  /// Returns null if [s] is not a recognisable, correctly-sized grid.
  static List<int>? tryParse(String? s) {
    if (s == null || s.isEmpty) return null;

    if (s.startsWith(_v2Prefix)) {
      try {
        final bytes = base64.decode(s.substring(_v2Prefix.length));
        if (bytes.length != cells) return null;
        return List<int>.generate(cells, (i) => bytes[i]);
      } catch (_) {
        return null;
      }
    }

    // Legacy: 100 hex nibbles.
    if (s.length != cells) return null;
    final out = List<int>.filled(cells, 0);
    for (int i = 0; i < cells; i++) {
      final c = s.codeUnitAt(i);
      int v;
      if (c >= 0x30 && c <= 0x39) {
        v = c - 0x30; // '0'-'9'
      } else if (c >= 0x41 && c <= 0x46) {
        v = c - 0x41 + 10; // 'A'-'F'
      } else if (c >= 0x61 && c <= 0x66) {
        v = c - 0x61 + 10; // 'a'-'f'
      } else {
        return null;
      }
      out[i] = v;
    }
    return out;
  }

  /// Parse, or fall back to an all-background (index 0) grid when invalid.
  static List<int> parseOrBlank(String? s) =>
      tryParse(s) ?? List<int>.filled(cells, 0);

  /// Encode [indices] to the most compatible string form (see class docs):
  /// legacy hex when every index <= 15, otherwise `v2:`+base64.
  static String encode(List<int> indices) {
    assert(indices.length == cells, 'grid must be $cells cells');
    var maxIdx = 0;
    for (final v in indices) {
      if (v > maxIdx) maxIdx = v;
    }
    if (maxIdx <= 15) {
      final sb = StringBuffer();
      for (final v in indices) {
        sb.write((v & 0xF).toRadixString(16));
      }
      return sb.toString();
    }
    final bytes = Uint8List(cells);
    for (int i = 0; i < cells; i++) {
      bytes[i] = indices[i] & 0xFF;
    }
    return _v2Prefix + base64.encode(bytes);
  }

  /// True if [s] is a valid grid in either encoding.
  static bool isValid(String? s) => tryParse(s) != null;

  /// A blank grid string (all background).
  static String get blank => '0' * cells;
}

/// A contiguous, named block of palette colours. A "set" is the unit that can
/// become a store SKU later (see [premium]/[sku]). Sets are **append-only** and
/// their [start] index must never move — indices are persisted inside user art.
@immutable
class WkPaletteSet {
  final String id;
  final String name;
  final int start; // first palette index in this set
  final int count; // number of colours
  final bool premium; // true once gated behind a purchase (see WkPalette.canAuthor)
  final String? sku; // Play Billing product id, when premium

  /// A retired set kept **only** so existing art that references its indices
  /// keeps rendering (a migration/legacy map). Legacy sets are never offered in
  /// the editor for authoring new art — see [WkPalette.authoringSets].
  final bool legacy;

  const WkPaletteSet({
    required this.id,
    required this.name,
    required this.start,
    required this.count,
    this.premium = false,
    this.sku,
    this.legacy = false,
  });

  int get end => start + count; // exclusive
  bool contains(int index) => index >= start && index < end;
}

/// The app-baked palette registry.
///
/// 🔒 **The rule: rendering is always free; only *authoring* is gated.** Every
/// palette set (including premium ones) is bundled in every build so a friend's
/// premium-palette avatar renders correctly for everyone. A purchase only
/// unlocks *creating* art with those colours — see [canAuthor].
///
/// ⚠️ [colors] and [sets] are **append-only**. Never reorder, recolour, or
/// remove an existing index: doing so silently rewrites every stored avatar that
/// referenced it. New colours go on the end, at index 16, 17, … up to 255.
class WkPalette {
  WkPalette._();

  static const List<Color> colors = [
    // ── Set "classic" (0–15) — the original 16. Index 0 is the background. ──
    Color(0xFF0F172A), // 0: Dark slate/Black (background)
    Color(0xFFFFFFFF), // 1: White
    Color(0xFFFF3366), // 2: Neon Pink
    Color(0xFFFF6600), // 3: Orange
    Color(0xFFFFCC00), // 4: Yellow
    Color(0xFF33CC66), // 5: Green
    Color(0xFF0099FF), // 6: Blue
    Color(0xFF9933FF), // 7: Purple
    Color(0xFFFF99CC), // 8: Light Pink
    Color(0xFFCCFF33), // 9: Lime
    Color(0xFF33FFFF), // A: Cyan
    Color(0xFF996633), // B: Brown
    Color(0xFF45A29E), // C: Dark Teal
    Color(0xFFCCCCCC), // D: Light Gray
    Color(0xFF66FCF1), // E: Wiltkey Bright Teal
    Color(0xFFFF3333), // F: Neon Red
    // ── Set "pastel" (16–31) — free extended set, softer/earthy tones. ──
    Color(0xFFFFD8B1), // 16: Peach
    Color(0xFFFF7F7F), // 17: Coral
    Color(0xFFE75480), // 18: Rose
    Color(0xFFB57EDC), // 19: Lavender
    Color(0xFF8E9BF0), // 20: Periwinkle
    Color(0xFF87CEEB), // 21: Sky
    Color(0xFF98FF98), // 22: Mint
    Color(0xFFA9BA9D), // 23: Sage
    Color(0xFF808000), // 24: Olive
    Color(0xFFE1AD01), // 25: Mustard
    Color(0xFFE2725B), // 26: Terracotta
    Color(0xFF915F6D), // 27: Mauve
    Color(0xFF6A5ACD), // 28: Slate Blue
    Color(0xFF008080), // 29: Deep Teal
    Color(0xFF36454F), // 30: Charcoal
    Color(0xFFFFFDD0), // 31: Cream
    // Future premium sets append here at index 32+.
  ];

  static const List<WkPaletteSet> sets = [
    // "classic" (0–15) is the ORIGINAL palette, now retired from authoring. It
    // stays in the registry purely as a migration/render map so every avatar
    // drawn before this update keeps rendering with its exact colours. New art
    // can no longer be drawn with these — see [authoringSets].
    WkPaletteSet(id: 'classic', name: 'Classic', start: 0, count: 16, legacy: true),
    WkPaletteSet(id: 'pastel', name: 'Pastel', start: 16, count: 16),
    // WkPaletteSet(id: 'neon-pro', name: 'Neon Pro', start: 32, count: 16,
    //   premium: true, sku: 'wk_palette_neon_pro'),  ← example future SKU
  ];

  static int get length => colors.length;

  /// Sets the editor may draw new art with (everything not [WkPaletteSet.legacy]).
  static List<WkPaletteSet> get authoringSets =>
      sets.where((s) => !s.legacy).toList(growable: false);

  /// The first drawable palette index — the default brush when a caller's
  /// requested default falls in a retired/legacy set.
  static int get firstAuthoringIndex =>
      authoringSets.isNotEmpty ? authoringSets.first.start : 0;

  /// True if [index] belongs to a set that can be drawn with right now.
  static bool isAuthoringIndex(int index) {
    final s = setOf(index);
    return s != null && !s.legacy && canAuthor(s);
  }

  /// Colour for [index]; unknown/out-of-range indices (e.g. a premium colour
  /// from a newer build than ours) fall back to the background so forward-
  /// incompatible pixels blend in rather than crash or flash a jarring colour.
  static Color colorAt(int index) =>
      (index >= 0 && index < colors.length) ? colors[index] : colors[0];

  /// Which set (if any) an index belongs to.
  static WkPaletteSet? setOf(int index) {
    for (final s in sets) {
      if (s.contains(index)) return s;
    }
    return null;
  }

  /// Whether the local user may *author* (draw) with [set].
  ///
  /// Rendering is never gated — only authoring. Today there is no entitlement
  /// system, so free sets are always allowed and premium sets are locked. When
  /// monetization (#7) lands, replace the `!set.premium` branch with a
  /// server-authoritative entitlement check keyed on [WkPaletteSet.sku].
  static bool canAuthor(WkPaletteSet set) => !set.premium;
}
