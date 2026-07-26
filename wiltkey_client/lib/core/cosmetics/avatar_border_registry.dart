import '../build_flavor.dart';
import '../entitlements/entitlement_service.dart';
import '../entitlements/product_ids.dart';
import 'avatar_border_ticker.dart';
import 'premium/premium_borders.dart';

/// A decorative overlay drawn on top of an avatar — a frame, a hat, an accessory.
///
/// Borders are usually **SVG assets** rendered over the pixel-art avatar (which
/// is inset to ~80% when a border is equipped; see [PixelArtAvatar]). Design
/// canvas is a square `viewBox="0 0 100 100"`; the avatar occupies (10,10)–
/// (90,90), and the SVG is transparent wherever the avatar should show through.
///
/// A border may instead be **animated**: set [animatedPaint] (a fixed-colour
/// [AvatarBorderPaint]) rather than [assetPath], and it renders as a live
/// [AnimatedAvatarBorder] driven by the shared clock. Animated borders are
/// broadcast art like SVG ones — a peer sees yours if their build carries the
/// id (both official builds do; a fork without the private overlay draws
/// nothing, exactly as for a missing premium SVG).
///
/// **Render-free rule (like palettes/themes):** a border always *renders* for
/// everyone — it's broadcast profile art, so a peer's premium border must show
/// up on your screen regardless of what you own. Ownership only gates whether
/// *you* may equip it locally.
class WkAvatarBorder {
  /// Stable id, persisted and broadcast. Never change once shipped.
  final String id;

  /// Human-facing name for the picker / shop.
  final String name;

  /// Bundled SVG asset path, or null for [none] and for animated borders.
  final String? assetPath;

  /// Live painter for an animated border (mutually exclusive with [assetPath]).
  /// Null for static SVG and [none] borders. Takes precedence when both are set.
  final AvatarBorderPaint? animatedPaint;

  /// Paid border (Play only). Free borders ([none], [tinfoil]) are false.
  final bool premium;

  const WkAvatarBorder({
    required this.id,
    required this.name,
    required this.assetPath,
    this.animatedPaint,
    this.premium = false,
  });

  /// True when this border renders via a live painter rather than an SVG.
  bool get isAnimated => animatedPaint != null;

  /// Play product id that unlocks this border (premium only).
  String get sku => WkProducts.avatarBorder(id);
}

class WkAvatarBorderRegistry {
  WkAvatarBorderRegistry._();

  /// The "no border" sentinel — the default until the user equips one.
  static const String noneId = 'none';

  static const WkAvatarBorder none = WkAvatarBorder(
    id: noneId,
    name: 'None',
    assetPath: null,
  );

  /// The joke free border, bundled in the public repo and available on BOTH
  /// flavors. On FOSS it's an equippable border; on Play it's part of the free
  /// tier alongside the paid ones.
  static const WkAvatarBorder tinfoil = WkAvatarBorder(
    id: 'tinfoil',
    name: 'Tinfoil Hat',
    assetPath: 'assets/borders/tinfoil_hat.svg',
  );

  // A small set of simple gradient frames — free, public, both flavors — so the
  // no-cost picker isn't just "none" and the joke hat. Plain rounded-square
  // gradient strokes (see `assets/borders/*_border.svg`).
  static const WkAvatarBorder ocean = WkAvatarBorder(
    id: 'ocean',
    name: 'Ocean',
    assetPath: 'assets/borders/ocean_border.svg',
  );
  static const WkAvatarBorder sunset = WkAvatarBorder(
    id: 'sunset',
    name: 'Sunset',
    assetPath: 'assets/borders/sunset_border.svg',
  );
  static const WkAvatarBorder meadow = WkAvatarBorder(
    id: 'meadow',
    name: 'Meadow',
    assetPath: 'assets/borders/meadow_border.svg',
  );
  static const WkAvatarBorder amethyst = WkAvatarBorder(
    id: 'amethyst',
    name: 'Amethyst',
    assetPath: 'assets/borders/amethyst_border.svg',
  );

  /// Free borders — always present, both flavors, no purchase. Order = picker
  /// order: none first (the default), the gradient set, then the joke hat.
  static const List<WkAvatarBorder> free = [
    none,
    ocean,
    sunset,
    meadow,
    amethyst,
    tinfoil,
  ];

  /// Every border that can RENDER in this build — the free set plus ALL premium
  /// borders, on every flavor. Borders are broadcast profile art, so a premium
  /// border MUST resolve via [byId] everywhere (a FOSS user has to see a Play
  /// peer's golden frame — that's the render-free rule above). The premium SVG
  /// source lives in a private repo and is overlaid onto the build machine; a
  /// public fork without that overlay gets an empty premiumBorders() and so
  /// simply renders none for an unknown id. Unlike themes (local-only UI, gated
  /// by kPlayStore), borders cross the wire — hence rendered on all flavors.
  static final List<WkAvatarBorder> all = [
    ...free,
    ...premiumBorders(),
  ];

  /// Borders the local user may pick from in their own picker: the free set
  /// always, plus premium borders only on the official Play build (where they
  /// can actually be bought). FOSS/forks omit premium here so the picker isn't
  /// cluttered with borders that can never be equipped — but those borders still
  /// RENDER on peers via [all]/[byId].
  static final List<WkAvatarBorder> equippable = [
    ...free,
    if (kPlayStore) ...premiumBorders(),
  ];

  /// Just the paid borders (drives the Shop's Borders tab, Play-only UI).
  static List<WkAvatarBorder> get premium =>
      all.where((b) => b.premium).toList(growable: false);

  static WkAvatarBorder byId(String? id) =>
      all.firstWhere((b) => b.id == id, orElse: () => none);

  /// Whether the local user may *equip* [border]. Free borders always; premium
  /// borders require the entitlement (and only exist on Play). Rendering a
  /// peer's border is never gated — this is only for the picker.
  static bool canEquip(WkAvatarBorder border) {
    if (!border.premium) return true;
    return EntitlementService.instance.premiumBorderUnlocked(border.id);
  }
}
