import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiltkey_client/core/custom_emoji.dart';
import 'package:wiltkey_client/core/theme/theme_registry.dart';
import 'package:wiltkey_client/features/chat/presentation/widgets/chat_markdown.dart';
import 'package:wiltkey_client/features/chat/presentation/widgets/link_warning_dialog.dart';
import 'package:wiltkey_client/features/chat/presentation/widgets/link_warning_easter_eggs.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: WiltkeyThemeRegistry.cyberpunk.build(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('ChatMarkdownText formatting tests', () {
    testWidgets('Renders plain text correctly', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const ChatMarkdownText(
            text: 'Hello world',
            style: TextStyle(fontSize: 14),
          ),
        ),
      );
      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('Renders bold and italic spans', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const ChatMarkdownText(
            text: 'This is **bold** and *italic* text',
            style: TextStyle(fontSize: 14),
          ),
        ),
      );

      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);

      final richText = tester.widget<RichText>(richTextFinder.first);
      final textSpan = richText.text as TextSpan;
      expect(textSpan.toPlainText(), 'This is bold and italic text');
    });

    testWidgets('Renders inline code container', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const ChatMarkdownText(
            text: 'Use `print()` to log',
            style: TextStyle(fontSize: 14),
          ),
        ),
      );

      expect(find.text('print()'), findsOneWidget);
    });

    testWidgets('Renders multi-line code block with copy button', (tester) async {
      const codeBlock = '```dart\nvoid main() {\n  print(123);\n}\n```';
      await tester.pumpWidget(
        _wrapWithTheme(
          const ChatMarkdownText(
            text: codeBlock,
            style: TextStyle(fontSize: 14),
          ),
        ),
      );

      expect(find.text('DART'), findsOneWidget);
      expect(find.text('void main() {\n  print(123);\n}'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('Renders headers, quotes, and bullet lists', (tester) async {
      const markdown = '# Main Title\n> Important quote\n- First point\n- Second point';
      await tester.pumpWidget(
        _wrapWithTheme(
          const ChatMarkdownText(
            text: markdown,
            style: TextStyle(fontSize: 14),
          ),
        ),
      );

      expect(find.text('Main Title'), findsOneWidget);
      expect(find.text('Important quote'), findsOneWidget);
      expect(find.text('First point'), findsOneWidget);
      expect(find.text('Second point'), findsOneWidget);
      expect(find.text('• '), findsNWidgets(2));
    });

    testWidgets('Renders custom emoji span when resolved', (tester) async {
      // 1x1 transparent PNG
      final dummyPng = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);

      final emojiMap = <String, CustomEmoji>{
        'party_cat': CustomEmoji(
          name: 'party_cat',
          imageB64: base64Encode(dummyPng),
          createdAtMs: 12345678,
        ),
      };

      await tester.pumpWidget(
        _wrapWithTheme(
          ChatMarkdownText(
            text: 'Hello :party_cat: friend!',
            emojiMap: emojiMap,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('Shows security warning dialog when clicking links', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const ChatMarkdownText(
            text: 'Check [our website](https://wiltkey.org) for details',
            style: TextStyle(fontSize: 14),
          ),
        ),
      );

      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);

      // Verify the link is rendered with label
      final richText = tester.widget<RichText>(richTextFinder.first);
      final textSpan = richText.text as TextSpan;
      expect(textSpan.toPlainText(), 'Check our website for details');

      // Test showLinkWarningDialog directly
      await tester.pumpWidget(
        _wrapWithTheme(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showLinkWarningDialog(
                context,
                Uri.parse('https://wiltkey.org'),
              ),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('EXTERNAL LINK WARNING'), findsOneWidget);
      expect(find.text('https://wiltkey.org'), findsOneWidget);
      expect(find.text("Visiting home base? Don't forget to star the repo."), findsOneWidget);
      expect(find.text('OPEN IN BROWSER'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    test('getLinkEasterEgg matches requested domains and falls back on other languages', () {
      // 1. artfacility.xyz
      expect(
        getLinkEasterEgg(Uri.parse('https://artfacility.xyz'), 'en'),
        'Looking for other awesome open source software?',
      );
      // 2. artfacility.com
      expect(
        getLinkEasterEgg(Uri.parse('https://artfacility.com'), 'en'),
        'I think you got the link wrong boss.',
      );
      // 3. xhamster
      expect(
        getLinkEasterEgg(Uri.parse('https://xhamster.com'), 'en'),
        'You know there are no hamsters on this one?',
      );
      // 4. facebook
      expect(
        getLinkEasterEgg(Uri.parse('https://facebook.com/group'), 'en'),
        "Warning: you're about to open the dumbest side of the internet.",
      );
      // 5. Rickroll
      expect(
        getLinkEasterEgg(Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), 'en'),
        "Sorry boss, they're trying to rickroll you.",
      );
      expect(
        getLinkEasterEgg(Uri.parse('https://youtu.be/dQw4w9WgXcQ'), 'en'),
        "Sorry boss, they're trying to rickroll you.",
      );
      // 6. Link shortener
      expect(
        getLinkEasterEgg(Uri.parse('https://bit.ly/secret-link'), 'en'),
        'Living the dangerous life I see...',
      );
      // 7. Non-English fallback (always returns null so localized warning is used)
      expect(
        getLinkEasterEgg(Uri.parse('https://artfacility.xyz'), 'de'),
        isNull,
      );
      expect(
        getLinkEasterEgg(Uri.parse('https://bit.ly/secret-link'), 'hu'),
        isNull,
      );
      expect(
        getLinkEasterEgg(Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), 'fr'),
        isNull,
      );
    });
  });
}
