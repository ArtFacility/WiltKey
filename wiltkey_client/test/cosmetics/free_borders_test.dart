import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiltkey_client/core/cosmetics/avatar_border_registry.dart';
import 'package:wiltkey_client/core/pixel_art_avatar.dart';

/// The free gradient borders are public (bundled SVGs), so this is a committed,
/// fork-safe regression guard.
void main() {
  const gradientIds = ['ocean', 'sunset', 'meadow', 'amethyst'];

  test('free set includes none, the four gradients, and tinfoil (in order)', () {
    final ids = WkAvatarBorderRegistry.free.map((b) => b.id).toList();
    expect(ids, ['none', 'ocean', 'sunset', 'meadow', 'amethyst', 'tinfoil']);
  });

  test('gradient borders are free, static SVG assets', () {
    for (final id in gradientIds) {
      final b = WkAvatarBorderRegistry.byId(id);
      expect(b.premium, isFalse, reason: '$id must be free');
      expect(b.isAnimated, isFalse);
      expect(b.assetPath, contains('assets/borders/'));
    }
  });

  testWidgets('each free gradient border renders over an avatar', (tester) async {
    for (final id in gradientIds) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PixelArtAvatar(
                hexString: PixelArtAvatar.generateIdenticon('sample'),
                size: 60,
                borderId: id,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 32));
      expect(tester.takeException(), isNull, reason: 'border $id threw');
    }
  });
}
