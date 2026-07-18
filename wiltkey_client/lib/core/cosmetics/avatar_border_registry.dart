import '../build_flavor.dart';
import '../entitlements/entitlement_service.dart';
import '../entitlements/product_ids.dart';
import 'premium/premium_borders.dart';

/// A decorative overlay drawn on top of an avatar — a frame, a hat, an accessory.
///
/// Borders are **SVG assets** rendered over the pixel-art avatar (which is inset
/// to ~80% when a border is equipped; see [PixelArtAvatar]). Design canvas is a
/// square `viewBox="0 0 100 100"`; the avatar occupies (10,10)–(90,90), and the
/// SVG is transparent wherever the avatar should show through.
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

  /// Bundled asset path, or null for [none] (draw nothing).
  final String? assetPath;

  /// Paid border (Play only). Free borders ([none], [tinfoil]) are false.
  final bool premium;

  const WkAvatarBorder({
    required this.id,
    required this.name,
    required this.assetPath,
    this.premium = false,
  });

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

  /// The one free border, bundled in the public repo and available on BOTH
  /// flavors. On FOSS it's the only equippable border; on Play it's the free
  /// tier alongside the paid ones.
  static const WkAvatarBorder tinfoil = WkAvatarBorder(
    id: 'tinfoil',
    name: 'Tinfoil Hat',
    assetPath: 'assets/borders/tinfoil_hat.svg',
  );

  /// Free borders — always present, both flavors, no purchase.
  static const List<WkAvatarBorder> free = [none, tinfoil];

  /// Everything selectable in this build: the free set, plus premium borders on
  /// the official Play build only (their SVG source lives in a private repo; the
  /// public stub returns none, so FOSS and forks see just the free borders).
  static final List<WkAvatarBorder> all = [
    ...free,
    if (kPlayStore) ...premiumBorders(),
  ];

  /// Just the paid borders (drives the Shop's Borders tab). Empty on FOSS.
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
