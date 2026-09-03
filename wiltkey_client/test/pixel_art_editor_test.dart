import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiltkey_client/core/pixel_art_avatar.dart';
import 'package:wiltkey_client/core/pixel_art_editor.dart';
import 'package:wiltkey_client/core/pixel_palette.dart';
import 'package:wiltkey_client/core/theme/theme_registry.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';

void main() {
  testWidgets('PixelArtAvatar renders with square corners (no rounding)', (tester) async {
    final hex = PixelArtAvatar.generateIdenticon('test_user');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PixelArtAvatar(
            hexString: hex,
            size: 64,
          ),
        ),
      ),
    );

    expect(find.byType(PixelArtAvatar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PixelArtAvatar),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    // Ensure ClipRRect is not used for rounding corners
    expect(
      find.descendant(
        of: find.byType(PixelArtAvatar),
        matching: find.byType(ClipRRect),
      ),
      findsNothing,
    );
  });

  testWidgets('PixelArtEditor displays fixed canvas, active palette, and switcher', (tester) async {
    String currentHex = PixelGrid.blank;
    final themeData = WiltkeyThemeRegistry.cyberpunk.build();

    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return PixelArtEditor(
                initialHex: currentHex,
                identiconSeed: 'user_123',
                onChanged: (hex) => currentHex = hex,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Canvas exists with 100 cells
    expect(find.byType(GridView), findsOneWidget);

    // Initial palette is Pastel
    expect(find.textContaining('PASTEL', findRichText: true), findsOneWidget);

    // Action chips exist
    expect(find.textContaining('CLEAR', findRichText: true), findsOneWidget);
    expect(find.textContaining('RANDOM', findRichText: true), findsOneWidget);
    expect(find.textContaining('IDENTICON', findRichText: true), findsOneWidget);
    expect(find.textContaining('ADD TO TEMPLATES', findRichText: true), findsOneWidget);

    // Tap the palette switcher button
    await tester.tap(find.textContaining('PASTEL', findRichText: true));
    await tester.pumpAndSettle();

    // Palette picker dialog opens
    expect(find.textContaining('SELECT PALETTE', findRichText: true), findsOneWidget);
    expect(find.textContaining('EDGY', findRichText: true), findsOneWidget);
  });
}
