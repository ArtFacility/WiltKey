import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiltkey_client/features/settings/presentation/theme_preview_screen.dart';
import 'package:wiltkey_client/core/theme/theme_registry.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  testWidgets('theme preview renders for every base theme', (tester) async {
    for (final d in [
      WiltkeyThemeRegistry.cyberpunk,
      WiltkeyThemeRegistry.garden,
      WiltkeyThemeRegistry.paperink,
    ]) {
      await tester.pumpWidget(_wrap(ThemePreviewScreen(descriptor: d)));
      // A few real frames: the sync visual + scrubber run their own tickers.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: 'theme ${d.id} threw');
    }
  });

  testWidgets('play-unlock button mounts the overlay effect and finishes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(ThemePreviewScreen(descriptor: WiltkeyThemeRegistry.cyberpunk)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // The effect buttons sit below the fold of the lazy ListView — scroll
    // until built. Cyberpunk uppercases labels.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final target = find.text(l10n.themePreviewPlayUnlock.toUpperCase());
    await tester.scrollUntilVisible(
      target,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(target, warnIfMissed: false);

    // The unlock sequence is finite (~1s); pump past it and make sure the
    // overlay entry removed itself without throwing.
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('fullscreen profile preview opens and renders', (tester) async {
    await tester.pumpWidget(
      _wrap(ThemePreviewScreen(descriptor: WiltkeyThemeRegistry.garden)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final target = find.text(l10n.themePreviewFullscreenProfile);
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(target, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Réka Kovács'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
