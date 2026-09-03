import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiltkey_client/core/cosmetics/avatar_border_registry.dart';
import 'package:wiltkey_client/core/pixel_art_avatar.dart';
import 'package:wiltkey_client/core/pixel_palette.dart';
import 'package:wiltkey_client/core/theme/theme_registry.dart';
import 'package:wiltkey_client/features/shell/presentation/wk_bottom_nav.dart';
import 'package:wiltkey_client/features/stories/presentation/story_composer_screen.dart';
import 'package:wiltkey_client/features/stories/presentation/widgets/themed_story_text_tag.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1.4.5 Avatar Border Cropping Tests', () {
    test('AvatarCropShape enum and WkAvatarBorder fields are correctly configured', () {
      final defaultBorder = WkAvatarBorderRegistry.none;
      expect(defaultBorder.cropShape, equals(AvatarCropShape.square));

      // Free borders retain sharp square edges
      final oceanBorder = WkAvatarBorderRegistry.ocean;
      expect(oceanBorder.cropShape, equals(AvatarCropShape.square));

      final customCircle = const WkAvatarBorder(
        id: 'test_circle',
        name: 'Test Circle',
        assetPath: null,
        cropShape: AvatarCropShape.circle,
      );
      expect(customCircle.cropShape, equals(AvatarCropShape.circle));
    });

    testWidgets('PixelArtAvatar applies ClipRRect when border cropShape is rounded', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PixelArtAvatar(
                hexString: '0000000000',
                size: 80,
                borderId: 'aurora',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('PixelArtAvatar applies ClipOval when border cropShape is circle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PixelArtAvatar(
                hexString: '0000000000',
                size: 80,
                borderId: 'bubbles',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ClipOval), findsOneWidget);
    });

    test('Premium animated borders (spinner, snake, bubbles) are registered with correct crop shapes', () {
      final allBorders = WkAvatarBorderRegistry.all;
      final ids = allBorders.map((b) => b.id).toList();

      expect(ids, contains('spinner'));
      expect(ids, contains('snake'));
      expect(ids, contains('bubbles'));

      final spinner = WkAvatarBorderRegistry.byId('spinner');
      expect(spinner.cropShape, equals(AvatarCropShape.circle));
      expect(spinner.isAnimated, isTrue);

      final snake = WkAvatarBorderRegistry.byId('snake');
      expect(snake.cropShape, equals(AvatarCropShape.square));
      expect(snake.isAnimated, isTrue);

      final bubbles = WkAvatarBorderRegistry.byId('bubbles');
      expect(bubbles.cropShape, equals(AvatarCropShape.circle));
      expect(bubbles.isAnimated, isTrue);
    });
  });

  group('v1.4.5 Story Studio Themed Text Tag Tests', () {
    test('StoryTextStyles contains all required built-in and themed background options', () {
      final styles = StoryTextStyles.options.map((o) => o['id']).toList();
      expect(styles, contains(StoryTextStyles.none));
      expect(styles, contains(StoryTextStyles.cyberpunk));
      expect(styles, contains(StoryTextStyles.garden));
      expect(styles, contains(StoryTextStyles.paperink));
      expect(styles, contains(StoryTextStyles.matrix));
      expect(styles, contains(StoryTextStyles.phosphor));
      expect(styles, contains(StoryTextStyles.crimson));
    });

    test('WkPalette colors and sets can be used for text tags', () {
      final classic = WkPalette.sets.firstWhere((s) => s.id == 'classic');
      expect(classic.count, equals(16));
      expect(WkPalette.colorAt(classic.start), isA<Color>());
    });
  });

  group('v1.4.5 Bottom Navigation Bar Constraints Tests', () {
    testWidgets('WkBottomNavBar stays anchored at bottom with 54dp height in Scaffold', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WiltkeyThemeRegistry.byId('cyberpunk').build(),
          home: Scaffold(
            body: const Center(child: Text('Main Content')),
            bottomNavigationBar: WkBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
              items: const [
                WkNavItem(Icons.people_outline, 'Contacts'),
                WkNavItem(Icons.chat_bubble_outline, 'Chats'),
                WkNavItem(Icons.adjust, 'Connect'),
                WkNavItem(Icons.settings_outlined, 'Settings'),
              ],
            ),
          ),
        ),
      );

      final navBarFinder = find.byType(WkBottomNavBar);
      expect(navBarFinder, findsOneWidget);

      final size = tester.getSize(navBarFinder);
      // Height should be exactly 54 (or 54 + safe area inset), never full screen height!
      expect(size.height, lessThanOrEqualTo(80));
      expect(size.height, greaterThanOrEqualTo(50));

      // Verify icons are rendered
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.byIcon(Icons.adjust), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });
  });

  group('v1.4.5 Story Studio Decoupled Canvas & Keyboard Stability Tests', () {
    testWidgets('Story canvas preserves AspectRatio and does not resize under keyboard', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WiltkeyThemeRegistry.byId('cyberpunk').build(),
          home: const MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.zero),
            child: StoryComposerScreen(initialMode: 'text'),
          ),
        ),
      );
      await tester.pump();

      final canvasFinder = find.byType(AspectRatio);
      expect(canvasFinder, findsOneWidget);
      final initialSize = tester.getSize(canvasFinder);

      // Simulate keyboard open with 300px bottom inset
      await tester.pumpWidget(
        MaterialApp(
          theme: WiltkeyThemeRegistry.byId('cyberpunk').build(),
          home: const MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)),
            child: StoryComposerScreen(initialMode: 'text'),
          ),
        ),
      );
      await tester.pump();

      final newSize = tester.getSize(canvasFinder);
      expect(newSize.height, equals(initialSize.height));
      expect(newSize.width, equals(initialSize.width));
    });
  });
}
