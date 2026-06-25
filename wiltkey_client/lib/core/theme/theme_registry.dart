import 'package:flutter/material.dart';
import 'themes/cyberpunk_theme.dart';
import 'themes/garden_theme.dart';
import 'themes/paperink_theme.dart';
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

  const WiltkeyThemeDescriptor({
    required this.id,
    required this.displayName,
    required this.tagline,
    required this.previewSwatchA,
    required this.previewSwatchB,
    required this.build,
  });
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

  /// All selectable themes, in display order.
  static const List<WiltkeyThemeDescriptor> all = [cyberpunk, garden, paperink];

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
