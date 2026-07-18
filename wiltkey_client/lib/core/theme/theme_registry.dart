import 'package:flutter/material.dart';
import 'themes/cyberpunk_theme.dart';
import 'themes/garden_theme.dart';
import 'themes/paperink_theme.dart';
import 'premium/premium_themes.dart';
import '../build_flavor.dart';
import '../entitlements/product_ids.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';

/// Describes one selectable theme. Everything the picker and controller need
/// lives here, so adding a theme is: write `themes/<x>_theme.dart`, then append
/// one [WiltkeyThemeDescriptor] to [WiltkeyThemeRegistry.all].
@immutable
class WiltkeyThemeDescriptor {
  /// Stable id persisted to disk. Never change once shipped.
  final String id;

  /// Human-facing name shown in the picker.
  final String displayName;

  /// One-line description for the picker card.
  final String tagline;

  /// Two swatches for a quick preview chip.
  final Color previewSwatchA;
  final Color previewSwatchB;

  final ThemeData Function() build;

  /// True for a paid theme. Premium themes are only ever listed on the official
  /// Play build (see [WiltkeyThemeRegistry.all]); the picker shows them with a
  /// lock until [EntitlementService.premiumThemeUnlocked] says otherwise. A theme
  /// is purely local UI — it never crosses the wire — so this gates *selecting*
  /// it, nothing about how anyone's messages render.
  final bool premium;

  const WiltkeyThemeDescriptor({
    required this.id,
    required this.displayName,
    required this.tagline,
    required this.previewSwatchA,
    required this.previewSwatchB,
    required this.build,
    this.premium = false,
  });

  /// The Play product id that unlocks this theme (premium themes only).
  String get sku => WkProducts.premiumTheme(id);
}

class WiltkeyThemeRegistry {
  WiltkeyThemeRegistry._();

  /// The id used before the user has chosen (boot default).
  static const String defaultId = 'cyberpunk';

  static const WiltkeyThemeDescriptor cyberpunk = WiltkeyThemeDescriptor(
    id: 'cyberpunk',
    displayName: 'Neon Grid',
    tagline: 'The original. Obsidian, glowing cyan, terminal type.',
    previewSwatchA: Color(0xFF0B0C10),
    previewSwatchB: Color(0xFF66FCF1),
    build: buildCyberpunkTheme,
  );

  static const WiltkeyThemeDescriptor garden = WiltkeyThemeDescriptor(
    id: 'garden',
    displayName: 'Dusk Garden',
    tagline: 'Soft soil tones, warm linen, petals for your budget.',
    previewSwatchA: Color(0xFF181D17),
    previewSwatchB: Color(0xFFE0A458),
    build: buildGardenTheme,
  );

  static const WiltkeyThemeDescriptor paperink = WiltkeyThemeDescriptor(
    id: 'paperink',
    displayName: 'Paper & Ink',
    tagline: 'Warm washi, sumi ink dilutions, vermilion hanko seal.',
    previewSwatchA: Color(0xFFF7F4EB),
    previewSwatchB: Color(0xFFC3402F),
    build: buildPaperinkTheme,
  );

  /// All selectable themes, in display order. Premium themes are appended only on
  /// the official Play build ([kPlayStore]); the FOSS build and any public fork see
  /// just the three base themes (premium source isn't in the public repo). Whether a
  /// listed premium theme is *usable* is a separate entitlement check (see the
  /// theme picker + EntitlementService) — a theme still renders locally regardless.
  static final List<WiltkeyThemeDescriptor> all = [
    cyberpunk,
    garden,
    paperink,
    if (kPlayStore) ...premiumThemes(),
  ];

  /// Every listed premium theme (empty on FOSS and on any public fork, where the
  /// premium source isn't present). Drives the Shop's Themes tab.
  static List<WiltkeyThemeDescriptor> get premium =>
      all.where((t) => t.premium).toList(growable: false);

  static WiltkeyThemeDescriptor byId(String? id) {
    return all.firstWhere((t) => t.id == id, orElse: () => cyberpunk);
  }
}

extension LocalizedThemeDescriptor on WiltkeyThemeDescriptor {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return displayName;
    if (id == 'cyberpunk') return l10n.themeCyberpunkName;
    if (id == 'garden') return l10n.themeGardenName;
    if (id == 'paperink') return l10n.themePaperinkName;
    return displayName;
  }

  String localizedTagline(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return tagline;
    if (id == 'cyberpunk') return l10n.themeCyberpunkDesc;
    if (id == 'garden') return l10n.themeGardenDesc;
    if (id == 'paperink') return l10n.themePaperinkDesc;
    return tagline;
  }
}
