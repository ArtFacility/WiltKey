import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'entitlements/entitlement_service.dart';

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
    // ── Set "saturated" (32–51) — PREMIUM. The vivid, high-chroma look of the
    //    original palette, brought back as a drawable set (the legacy "classic"
    //    set is render-only). Includes white, which the free pastel set lacks.
    Color(0xFFFF3366), // 32: Neon Pink
    Color(0xFFFF00A0), // 33: Hot Magenta
    Color(0xFFB026FF), // 34: Electric Purple
    Color(0xFF7C3AED), // 35: Vivid Violet
    Color(0xFF0066FF), // 36: Electric Blue
    Color(0xFF00A3FF), // 37: Azure
    Color(0xFF00E5FF), // 38: Cyan
    Color(0xFF00FFD1), // 39: Aqua
    Color(0xFF00FF87), // 40: Spring Green
    Color(0xFF22DD44), // 41: Vivid Green
    Color(0xFFCCFF00), // 42: Lime
    Color(0xFF9EFF00), // 43: Chartreuse
    Color(0xFFFFE500), // 44: Yellow
    Color(0xFFFFB300), // 45: Amber
    Color(0xFFFF6A00), // 46: Orange
    Color(0xFFFF3D00), // 47: Vermilion
    Color(0xFFFF1744), // 48: Neon Red
    Color(0xFFE5004C), // 49: Crimson
    Color(0xFFFF4D8D), // 50: Rose
    Color(0xFFFFFFFF), // 51: White
    // ── Set "edgy" (52–71) — PREMIUM. Dark greys/blacks with strong reds.
    Color(0xFF08090B), // 52: Near Black
    Color(0xFF121317), // 53: Ink
    Color(0xFF1C1F26), // 54: Gunmetal
    Color(0xFF2A2E37), // 55: Charcoal
    Color(0xFF3A404B), // 56: Slate
    Color(0xFF4E5561), // 57: Steel
    Color(0xFF6B7280), // 58: Ash
    Color(0xFF9199A5), // 59: Smoke
    Color(0xFFD5D9E0), // 60: Bone
    Color(0xFF4A0008), // 61: Blood
    Color(0xFF6B0010), // 62: Dried Blood
    Color(0xFF8A0F1E), // 63: Oxblood
    Color(0xFFA80B22), // 64: Crimson
    Color(0xFFC1121F), // 65: Blood Red
    Color(0xFFE01E37), // 66: Strong Red
    Color(0xFFFF2D3F), // 67: Scarlet
    Color(0xFFFF5C4D), // 68: Ember
    Color(0xFF8B3A2E), // 69: Rust
    Color(0xFFB45B3E), // 70: Copper
    Color(0xFF3D1E3C), // 71: Bruise
    // ── Set "grasstoucher" (72–91) — PREMIUM. Nature: foliage, earth, water.
    Color(0xFF14301F), // 72: Deep Forest
    Color(0xFF1E4A2E), // 73: Pine
    Color(0xFF2F6B3A), // 74: Moss
    Color(0xFF3E8E4F), // 75: Fern
    Color(0xFF4CAF50), // 76: Grass
    Color(0xFF7CC96B), // 77: Spring Leaf
    Color(0xFFA8DE8B), // 78: Young Shoot
    Color(0xFFCDE9A8), // 79: Pale Leaf
    Color(0xFF4A3728), // 80: Bark
    Color(0xFF6B4F35), // 81: Earth
    Color(0xFF8B6B4A), // 82: Clay
    Color(0xFFC2A878), // 83: Sand
    Color(0xFFE4D2A8), // 84: Wheat
    Color(0xFF9AD1F0), // 85: Open Sky
    Color(0xFF4A90A4), // 86: River
    Color(0xFF27596B), // 87: Deep Water
    Color(0xFF7D8471), // 88: Stone
    Color(0xFFA3B18A), // 89: Lichen
    Color(0xFFE8A0BF), // 90: Bloom
    Color(0xFFF2C6DE), // 91: Petal
    // Future premium sets append here at index 92+.
  ];

  static const List<WkPaletteSet> sets = [
    // "classic" (0–15) is the ORIGINAL palette, now retired from authoring. It
    // stays in the registry purely as a migration/render map so every avatar
    // drawn before this update keeps rendering with its exact colours. New art
    // can no longer be drawn with these — see [authoringSets].
    WkPaletteSet(id: 'classic', name: 'Classic', start: 0, count: 16, legacy: true),
    WkPaletteSet(id: 'pastel', name: 'Pastel', start: 16, count: 16),
    // Premium packs. Each `sku` MUST equal WkProducts.palettePack(id) —
    // 'wk_palette_<id>' — since canAuthor resolves ownership by set id.
    WkPaletteSet(
      id: 'saturated',
      name: 'Saturated',
      start: 32,
      count: 20,
      premium: true,
      sku: 'wk_palette_saturated',
    ),
    WkPaletteSet(
      id: 'edgy',
      name: 'Edgy',
      start: 52,
      count: 20,
      premium: true,
      sku: 'wk_palette_edgy',
    ),
    WkPaletteSet(
      id: 'grasstoucher',
      name: 'Grasstoucher',
      start: 72,
      count: 20,
      premium: true,
      sku: 'wk_palette_grasstoucher',
    ),
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
  /// Rendering is never gated — only authoring. Free sets are always allowed;
  /// premium sets resolve through [EntitlementService], which applies the flavor
  /// rules: on the Play build the pack must be purchased, on the FOSS build every
  /// pack is free (palettes are "just adjustments" already in the open source).
  /// Client-side by design — a premium colour only ever affects the buyer's own
  /// art, and every build renders every index regardless.
  static bool canAuthor(WkPaletteSet set) {
    if (!set.premium) return true;
    return EntitlementService.instance.palettePackUnlocked(set.id);
  }
}
