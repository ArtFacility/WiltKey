import 'package:flutter/material.dart';
import 'wiltkey_tokens.dart';

/// Where a budget indicator is being rendered. Themes may choose a different
/// size/granularity per slot (e.g. a compact flower in a list row vs. a labelled
/// pair of flowers on the detail screen).
enum BudgetIndicatorVariant { listRow, chatHeader, detail }

/// Semantic badge kinds. Copy stays neutral; each theme decides casing/shape via
/// tokens (`uppercaseLabels`).
enum StatusBadgeKind { secured, wilted, archived, group, privateNode, host }

/// Resolved color/label/icon for a status badge. Shared by all themes so copy
/// and semantic color stay consistent; only the *shape* differs per theme.
@immutable
class BadgeSpec {
  final Color color;
  final String text;
  final IconData? icon;
  const BadgeSpec(this.color, this.text, this.icon);
}

BadgeSpec badgeSpec(WiltkeyTokens t, StatusBadgeKind kind, String? label) {
  final upper = t.uppercaseLabels;
  switch (kind) {
    case StatusBadgeKind.secured:
      return BadgeSpec(
        t.positive,
        label ?? (upper ? 'SECURED' : 'Secured'),
        null,
      );
    case StatusBadgeKind.wilted:
      return BadgeSpec(
        t.danger,
        label ?? (upper ? 'LOCKED' : 'Locked'),
        Icons.lock_outline,
      );
    case StatusBadgeKind.archived:
      return BadgeSpec(
        t.textTertiary,
        label ?? (upper ? 'ARCHIVED' : 'Archived'),
        Icons.inventory_2_outlined,
      );
    case StatusBadgeKind.group:
      return BadgeSpec(
        t.identity,
        label ?? (upper ? 'GROUP' : 'Group'),
        Icons.group_outlined,
      );
    case StatusBadgeKind.privateNode:
      return BadgeSpec(
        t.warning,
        label ?? (upper ? 'PRIVATE NODE' : 'Private node'),
        Icons.hub_outlined,
      );
    case StatusBadgeKind.host:
      return BadgeSpec(
        t.identity,
        label ?? (upper ? 'HOST' : 'Host'),
        Icons.star_outline,
      );
  }
}

/// Phase of the proximity sync sequence, driven by the pairing/group screens and
/// rendered by the theme's [WiltkeyComponents.syncVisual] effect.
///
/// `scanning` is implemented in both themes today (cyberpunk: radar, garden:
/// meadow field). The later states are reserved for the "vine → bloom" pairing
/// animation session — see `documentation/theming/ANIMATION_TODO.md`.
enum SyncVisualState { scanning, connecting, transferring, success }

/// A theme-agnostic discovery "blip" for [WiltkeyComponents.syncVisual]. The
/// proximity layer maps its concrete `DiscoveredBleDevice` onto this so the
/// theme/effect layer never imports a feature controller.
@immutable
class SyncBlip {
  /// Stable id (used to keep a blip's on-screen position/growth across frames).
  final String id;

  /// Signal strength normalised to 0 (far / weak) .. 1 (near / strong).
  final double strength;

  /// Stable bearing in radians; used only for a consistent horizontal placement.
  final double angle;

  /// True if this is a Wiltkey peer (vs. a generic BLE device).
  final bool isWiltkey;

  /// True if within pairing reach (the screens' RSSI gate).
  final bool isNear;

  /// True if this blip represents a group (tinted with the `identity` accent).
  final bool isGroup;

  const SyncBlip({
    required this.id,
    required this.strength,
    required this.angle,
    this.isWiltkey = false,
    this.isNear = false,
    this.isGroup = false,
  });
}

/// One member's slice of a group budget, theme-agnostic.
@immutable
class MemberBudget {
  /// 0..1 of this member's remaining budget.
  final double fraction;

  /// The member's key hash — used to pick a *stable* identity colour (see
  /// [memberPaletteColor]) so a member's flower/bar slice and their chat bubble
  /// always read as the same colour, regardless of roster order.
  final String keyHash;
  final bool isSelf;
  final bool isHost;
  final bool isWilted;

  const MemberBudget({
    required this.fraction,
    this.keyHash = '',
    this.isSelf = false,
    this.isHost = false,
    this.isWilted = false,
  });
}

/// Stable per-member identity colours (in the spirit of the identicon palette).
/// A member's colour is derived from their key hash — NOT their position in the
/// roster — so the same person keeps the same colour everywhere it's shown (the
/// group budget flowers/bars and their chat-bubble name + border) and never
/// shuffles when members join/leave or the list reorders.
const List<Color> kMemberPalette = [
  Color(0xFFFFD54F), // amber
  Color(0xFF45A29E), // teal
  Color(0xFFFF8A65), // orange
  Color(0xFF64B5F6), // blue
  Color(0xFFBA68C8), // violet
  Color(0xFF81C784), // green
];

/// Deterministic palette index for a member key hash. Sums code units so it's
/// identical across devices/sessions for a given id (unlike `String.hashCode`).
int _memberColorIndex(String keyHash) {
  if (keyHash.isEmpty) return 0;
  var sum = 0;
  for (final u in keyHash.codeUnits) {
    sum = (sum + u) & 0x7fffffff;
  }
  return sum % kMemberPalette.length;
}

/// The stable identity colour for a regular group member (self/host get their
/// own accents at the call site).
Color memberPaletteColor(String keyHash) =>
    kMemberPalette[_memberColorIndex(keyHash)];

/// The component factory: the set of widgets whose *shape* (not just color)
/// differs between themes. App code calls these semantic builders and never
/// references a concrete widget like `SegmentedChargeBar` or `PetalFlower`.
///
/// A new theme implements this once; no call site changes.
///
/// RULE: only put something here if two themes genuinely need different widget
/// trees. Everything else (buttons, cards, inputs, rows, app bars) is a plain
/// token consumer styled through [ThemeData] + `context.wk`.
abstract class WiltkeyComponents {
  /// Budget readout. `ourFraction`/`theirFraction` are each the lane's share of
  /// the WHOLE pad (so for a 1:1 chat each maxes at ~0.5).
  ///
  /// [split] distinguishes the two gauge modes:
  /// - `true` (1:1): a two-sided gauge — our half vs the peer's half, each in its
  ///   own colour. A fresh chat reads as a full glyph split down the middle.
  /// - `false` (group / single value): a single gauge driven by `ourFraction`
  ///   (0..1), one colour; `theirFraction` is ignored.
  Widget budgetIndicator({
    required double ourFraction,
    double theirFraction = 0,
    required bool isWilted,
    bool split = false,
    BudgetIndicatorVariant variant = BudgetIndicatorVariant.listRow,
    String? semanticLabel,
  });

  /// Whole-group budget readout (one slice per member + empty lane slots).
  Widget groupBudgetIndicator({
    required List<MemberBudget> members,
    int emptySlots = 0,
  });

  /// A small status pill/chip. Copy is supplied neutral; theme handles casing.
  Widget statusBadge(
    BuildContext context,
    StatusBadgeKind kind, {
    String? label,
  });

  /// A screen/section title (serif in garden, mono-caps in cyberpunk).
  Widget screenTitle(BuildContext context, String text, {String? subtitle});

  /// Wraps a screen body with the theme's ambient backdrop (gradients,
  /// particles, scanlines, …). Cyberpunk is flat; garden adds gradients +
  /// optional fireflies.
  Widget ambientBackground({required Widget child});

  /// The proximity sync effect. Cyberpunk returns the radar (for `scanning`);
  /// garden returns a meadow whose discovered devices bloom as flowers. `blips`
  /// is only meaningful while [SyncVisualState.scanning]; `progress` (0..1)
  /// drives the later vine/bloom states; `log` is the cyberpunk terminal tail
  /// (ignored by garden); `accent` optionally tints the bloom (e.g. the group
  /// `identity` colour for the join flow). Each effect owns its controller.
  Widget syncVisual({
    required SyncVisualState state,
    double progress = 0,
    List<SyncBlip> blips = const [],
    List<String> log = const [],
    Color? accent,
  });

  /// The PIN entry progress readout. `entered` of `length` digits are filled;
  /// `error` flags a failed attempt. Cyberpunk = a row of dots; garden = a small
  /// entry flower that grows a petal per digit (full bloom at `length`).
  Widget pinProgress(
    BuildContext context, {
    required int entered,
    required int length,
    required bool error,
  });

  /// A full-screen unlock transition played on a correct PIN. It animates, then
  /// calls [onDone] (the caller removes the overlay). Garden = a flower blooms
  /// then cross-fades into the app; cyberpunk = a quick fade. Both must call
  /// [onDone] even under reduce-motion (fade only).
  Widget unlockTransition({required VoidCallback onDone});

  /// A full-screen self-destruct overlay. It absorbs input, plays a destruction
  /// sequence ending on an opaque wiped frame, then calls [onDone] — at which
  /// point the caller performs the real wipe + navigation and removes the entry.
  /// Garden = colours rot to brown while a flower greys and sheds its petals;
  /// cyberpunk = a data-corruption glitch collapsing to black. Reduce-motion: a
  /// quick fade. Both must call [onDone].
  Widget nukeOverlay({required VoidCallback onDone});

  /// Optional: warm up anything heavy the [unlockTransition] needs (e.g. large
  /// glyph rasterization, blur shaders) while the lock screen is idle, so the
  /// first play is smooth. Called once when the PIN screen appears. Default
  /// no-op; only themes with a costly first frame need to override it.
  void precacheUnlock(BuildContext context) {}
}

/// Non-lerping [ThemeExtension] that carries the active theme's component
/// factory. Widget trees can't interpolate, so [lerp] snaps at the midpoint of a
/// theme transition.
@immutable
class WiltkeyComponentsExt extends ThemeExtension<WiltkeyComponentsExt> {
  final WiltkeyComponents components;

  const WiltkeyComponentsExt(this.components);

  @override
  WiltkeyComponentsExt copyWith({WiltkeyComponents? components}) =>
      WiltkeyComponentsExt(components ?? this.components);

  @override
  WiltkeyComponentsExt lerp(
    ThemeExtension<WiltkeyComponentsExt>? other,
    double t,
  ) {
    if (other is! WiltkeyComponentsExt) return this;
    return t < 0.5 ? this : other;
  }
}
