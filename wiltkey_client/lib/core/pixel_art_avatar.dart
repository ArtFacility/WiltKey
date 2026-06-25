import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

class PixelArtAvatar extends StatelessWidget {
  final String hexString; // 100 chars, e.g. "0123..."
  final double size;

  const PixelArtAvatar({
    super.key,
    required this.hexString,
    required this.size,
  });

  // Curated 16-color palette
  static const List<Color> palette = [
    Color(0xFF0F172A), // 0: Dark slate/Black (background)
    Color(0xFFFFFFFF), // 1: White
    Color(0xFFFF3366), // 2: Neon Pink
    Color(0xFFFF6600), // 3: Orange
    Color(0xFFFFCC00), // 4: Yellow
    Color(0xFF33CC66), // 5: Green
    Color(0xFF0099FF), // 6: Blue
    Color(0xFF9933FF), // 7: Purple
    Color(0xFFFF99CC), // 8: Light Pink
    Color(0xFFCCFF33), // 9: Lime
    Color(0xFF33FFFF), // A: Cyan
    Color(0xFF996633), // B: Brown
    Color(0xFF45A29E), // C: Dark Teal
    Color(0xFFCCCCCC), // D: Light Gray
    Color(0xFF66FCF1), // E: Wiltkey Bright Teal
    Color(0xFFFF3333), // F: Neon Red
  ];

  @override
  Widget build(BuildContext context) {
    final String cleanHex = (hexString.length == 100 && _isValidHex(hexString))
        ? hexString
        : '0' * 100;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF45A29E).withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: CustomPaint(
          size: Size(size, size),
          painter: _PixelArtPainter(cleanHex),
        ),
      ),
    );
  }

  bool _isValidHex(String hex) {
    final hexRegex = RegExp(r'^[0-9a-fA-F]{100}$');
    return hexRegex.hasMatch(hex);
  }

  static String generateIdenticon(String key) {
    if (key.isEmpty) return '0' * 100;

    // Symmetric identicon generator
    final hash = sha256.convert(utf8.encode(key)).bytes;
    final List<String> grid = List.filled(100, '0');

    // Choose 2 distinct colors from the palette to use in this identicon
    final int idx1 = (hash[0] % 15) + 1;
    int idx2 = (hash[1] % 15) + 1;
    if (idx1 == idx2) {
      idx2 = (idx2 % 15) + 1;
    }

    final color1Char = idx1.toRadixString(16);
    final color2Char = idx2.toRadixString(16);

    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 5; x++) {
        final byteIdx = (y * 5 + x) % hash.length;
        final val = hash[byteIdx];

        String colorChar = '0';
        if (val % 3 == 1) {
          colorChar = color1Char;
        } else if (val % 3 == 2) {
          colorChar = color2Char;
        }

        grid[y * 10 + x] = colorChar;
        grid[y * 10 + (9 - x)] = colorChar;
      }
    }
    return grid.join();
  }
}

class _PixelArtPainter extends CustomPainter {
  final String hex;
  _PixelArtPainter(this.hex);

  @override
  void paint(Canvas canvas, Size size) {
    final double pixelSize = size.width / 10.0;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int y = 0; y < 10; y++) {
      for (int x = 0; x < 10; x++) {
        final int index = y * 10 + x;
        final char = hex[index];
        final int colorIndex = int.parse(char, radix: 16);
        paint.color = PixelArtAvatar.palette[colorIndex];
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
    return oldDelegate.hex != hex;
  }
}
