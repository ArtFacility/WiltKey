/// Stable Google Play product identifiers for Phase-A monetization.
///
/// These strings are the app's permanent contract with the Play Console — once a
/// product ships they can NEVER change (Play keys ownership by this id). Cosmetics
/// are managed (non-consumable) products; [plusSubscription] is a subscription.
///
/// Premium themes and palette packs are keyed by their content id so a single
/// convention covers any number of future SKUs without touching this file:
///   theme  "midnight"  -> "wk_theme_midnight"
///   palette "autumn"   -> "wk_palette_autumn"
///
/// FOSS builds never reference these (no billing path is compiled in); see
/// [EntitlementService] and the native `wiltkey/billing` bridge under src/play/.
class WkProducts {
  WkProducts._();

  /// The "WiltKey Plus" recurring subscription — the only server-cost perk
  /// (72h offline hold vs 24h free; future capacity perks extend the same sub).
  static const String plusSubscription = 'wk_plus';

  /// One-time unlock for the larger OTP pad size at BLE pairing.
  static const String largerPads = 'wk_pads_large';

  /// Managed product id for a premium theme, derived from its registry id.
  static String premiumTheme(String themeId) => 'wk_theme_$themeId';

  /// Managed product id for a palette pack, derived from its pack id.
  static String palettePack(String packId) => 'wk_palette_$packId';

  /// Managed product id for an avatar border, derived from its border id.
  static String avatarBorder(String borderId) => 'wk_border_$borderId';

  /// True when [productId] follows the avatar-border id convention.
  static bool isAvatarBorder(String productId) =>
      productId.startsWith('wk_border_');

  /// True when [productId] follows the premium-theme id convention.
  static bool isPremiumTheme(String productId) =>
      productId.startsWith('wk_theme_');

  /// True when [productId] follows the palette-pack id convention.
  static bool isPalettePack(String productId) =>
      productId.startsWith('wk_palette_');
}
