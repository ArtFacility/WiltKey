import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'pixel_palette.dart';
import 'cosmetics/avatar_border_registry.dart';
import 'cosmetics/avatar_border_ticker.dart';

/// Renders a 10x10 pixel-art grid. [hexString] is the grid in either supported
/// encoding (legacy 100-char hex or `v2:`+base64 — see [PixelGrid]); invalid or
/// empty values render as a blank (all-background) grid.
///
/// When [borderId] names an equipped avatar border, the pixel body is inset to
/// 80% and the border's SVG is overlaid on top (design canvas 100x100, avatar in
/// the centre 80%). A peer's border comes from their broadcast profile; the local
/// user's from [AvatarBorderController]. Null/none = the plain framed avatar.
class PixelArtAvatar extends StatelessWidget {
  final String hexString;
  final double size;

  /// Equipped border id (see [WkAvatarBorderRegistry]). Null or 'none' → no
  /// overlay, and the classic thin teal frame is kept.
  final String? borderId;

  const PixelArtAvatar({
    super.key,
    required this.hexString,
    required this.size,
    this.borderId,
  });

  /// Back-compat alias for the classic 16 colours. New code should use
  /// [WkPalette.colors] / [WkPalette.colorAt].
  static List<Color> get palette => WkPalette.colors;

  @override
  Widget build(BuildContext context) {
    final border = WkAvatarBorderRegistry.byId(borderId);
    final asset = border.assetPath;

    // No border equipped → the original framed avatar, unchanged.
    if (asset == null && !border.isAnimated) {
      return _pixelBody(size, framed: true);
    }

    // Border equipped → determine inset scale based on border crop shape.
    // Circular borders fill the porthole circle (1.02x) so the avatar is prominently
    // sized and doesn't leave empty purple background margins; square/rounded frames inset to 80-82%.
    final double inner = switch (border.cropShape) {
      AvatarCropShape.circle => size * 1.02,
      AvatarCropShape.rounded => size * 0.82,
      AvatarCropShape.square => size * 0.80,
    };
    Widget body = _pixelBody(inner, framed: false);

    switch (border.cropShape) {
      case AvatarCropShape.circle:
        body = ClipOval(
          child: SizedBox(
            width: size * 0.84,
            height: size * 0.84,
            child: Center(child: body),
          ),
        );
        break;
      case AvatarCropShape.rounded:
        final radius = inner * (border.cornerRadiusFactor ?? 0.15);
        body = ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: body,
        );
        break;
      case AvatarCropShape.square:
        break;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          body,
          Positioned.fill(
            child: border.isAnimated
                ? AnimatedAvatarBorder(paint: border.animatedPaint!)
                : SvgPicture.asset(
                    asset!,
                    fit: BoxFit.contain,
                    // A missing premium asset (fork without the private repo)
                    // just renders nothing rather than throwing.
                    placeholderBuilder: (_) => const SizedBox.shrink(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _pixelBody(double s, {required bool framed}) {
    final indices = PixelGrid.parseOrBlank(hexString);
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        border: framed
            ? Border.all(
                color: const Color(0xFF45A29E).withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: CustomPaint(
        size: Size(s, s),
        painter: _PixelArtPainter(indices),
      ),
    );
  }

  /// Deterministic, horizontally-symmetric identicon derived from [key], drawn
  /// from the current authoring palette (so auto-avatars match the live colour
  /// system). Regenerated on the fly — no stored data depends on its encoding.
  static String generateIdenticon(String key) {
    if (key.isEmpty) return PixelGrid.blank;

    final hash = sha256.convert(utf8.encode(key)).bytes;
    final grid = List<int>.filled(PixelGrid.cells, 0);

    // Colour choices: every authoring-palette index (background excluded). Falls
    // back to the whole registry if no authoring set is available.
    final choices = <int>[];
    for (final s in WkPalette.authoringSets) {
      for (int i = s.start; i < s.end && i < WkPalette.length; i++) {
        if (i != 0) choices.add(i);
      }
    }
    if (choices.isEmpty) {
      for (int i = 1; i < WkPalette.length; i++) {
        choices.add(i);
      }
    }

    // Two distinct non-background colours, deterministic from the hash.
    final int idx1 = choices[hash[0] % choices.length];
    int idx2 = choices[hash[1] % choices.length];
    if (idx1 == idx2) {
      idx2 = choices[(hash[1] + 1) % choices.length];
    }

    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 5; x++) {
        final byteIdx = (y * 5 + x) % hash.length;
        final val = hash[byteIdx];

        int colorIdx = 0;
        if (val % 3 == 1) {
          colorIdx = idx1;
        } else if (val % 3 == 2) {
          colorIdx = idx2;
        }

        grid[y * 10 + x] = colorIdx;
        grid[y * 10 + (9 - x)] = colorIdx;
      }
    }
    return PixelGrid.encode(grid);
  }
}

class _PixelArtPainter extends CustomPainter {
  final List<int> indices;
  _PixelArtPainter(this.indices);

  @override
  void paint(Canvas canvas, Size size) {
    final double pixelSize = size.width / 10.0;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 10; x++) {
        final int index = y * 10 + x;
        paint.color = WkPalette.colorAt(indices[index]);
        canvas.drawRect(
          Rect.fromLTWH(
            x * pixelSize,
            y * pixelSize,
            pixelSize + 0.1,
            pixelSize + 0.1,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelArtPainter oldDelegate) {
    if (identical(oldDelegate.indices, indices)) return false;
    if (oldDelegate.indices.length != indices.length) return true;
    for (int i = 0; i < indices.length; i++) {
      if (oldDelegate.indices[i] != indices[i]) return true;
    }
    return false;
  }
}
