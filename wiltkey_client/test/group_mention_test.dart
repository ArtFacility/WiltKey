import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiltkey_client/core/theme/theme_registry.dart';
import 'package:wiltkey_client/features/chat/presentation/widgets/chat_markdown.dart';
import 'package:wiltkey_client/features/chat/presentation/widgets/mention_autocomplete_bar.dart';

void main() {
  group('activeMentionQuery parser', () {
    test('extracts query when typing @ at start of input', () {
      expect(activeMentionQuery('@', 1), equals(''));
      expect(activeMentionQuery('@nau', 4), equals('nau'));
      expect(activeMentionQuery('@ALICE', 6), equals('ALICE'));
    });

    test('extracts query when preceded by space or newline', () {
      expect(activeMentionQuery('Hello @', 7), equals(''));
      expect(activeMentionQuery('Hello @mad', 10), equals('mad'));
      expect(activeMentionQuery('Line 1\n@bob', 11), equals('bob'));
    });

    test('returns null for email-like tokens without leading space', () {
      expect(activeMentionQuery('user@domain.com', 7), isNull);
      expect(activeMentionQuery('test@', 5), isNull);
    });

    test('returns null when caret is not on an active mention', () {
      expect(activeMentionQuery('Hello world', 5), isNull);
      expect(activeMentionQuery('@Alice is here', 14), isNull);
    });
  });

  group('GroupMentionCandidate shortcode derivation', () {
    test('derives 3-5 char uppercase alphanumeric shortcode', () {
      expect(GroupMentionCandidate.deriveShortCode('Nauron21', 'key123'), equals('NAURO'));
      expect(GroupMentionCandidate.deriveShortCode('Bob', 'key456'), equals('BOB'));
      expect(GroupMentionCandidate.deriveShortCode('---', 'e2857c67'), equals('E2857'));
    });
  });

  group('MentionAutocompleteBar widget', () {
    testWidgets('shows suggestions when typing @ and inserts shortcode on tap', (tester) async {
      final controller = TextEditingController(text: 'Hey @');
      controller.selection = const TextSelection.collapsed(offset: 5);

      final candidates = [
        const GroupMentionCandidate(
          keyHash: 'hash_alice',
          name: 'Alice Cooper',
          shortCode: 'ALICE',
        ),
        const GroupMentionCandidate(
          keyHash: 'hash_bob',
          name: 'Bob Marley',
          shortCode: 'BOB',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: WiltkeyThemeRegistry.cyberpunk.build(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    MentionAutocompleteBar(
                      controller: controller,
                      candidates: candidates,
                    ),
                    TextField(controller: controller),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Both candidates should be visible
      expect(find.text('Alice Cooper'), findsOneWidget);
      expect(find.text('@ALICE'), findsOneWidget);
      expect(find.text('Bob Marley'), findsOneWidget);
      expect(find.text('@BOB'), findsOneWidget);

      // Tap on Alice
      await tester.tap(find.text('Alice Cooper'));
      await tester.pumpAndSettle();

      // Controller should now contain "Hey @ALICE "
      expect(controller.text, equals('Hey @ALICE '));
      expect(controller.selection.baseOffset, equals(11));
    });
  });

  group('ChatMarkdownText mention rendering', () {
    testWidgets('renders highlighted mention pill for current user', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WiltkeyThemeRegistry.cyberpunk.build(),
          home: const Scaffold(
            body: ChatMarkdownText(
              text: 'Hey @NAUR0 what do you think?',
              myShortNick: 'NAUR0',
              groupMembersMap: {'NAUR0': 'Nauron', 'ALICE': 'Alice'},
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Mention pill for current user should be rendered
      expect(find.text('@Nauron'), findsOneWidget);
    });

    testWidgets('renders mention pill with display name for other members', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WiltkeyThemeRegistry.cyberpunk.build(),
          home: const Scaffold(
            body: ChatMarkdownText(
              text: 'cc @ALICE please check',
              myShortNick: 'NAUR0',
              groupMembersMap: {'ALICE': 'Alice Cooper'},
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('@Alice Cooper'), findsOneWidget);
    });
  });
}
