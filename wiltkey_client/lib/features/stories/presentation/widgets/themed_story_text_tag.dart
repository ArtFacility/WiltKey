import 'package:flutter/material.dart';
import '../../../../core/theme/wiltkey_tokens.dart';

/// Available themed background style identifiers for Story Text Tags.
class StoryTextStyles {
  StoryTextStyles._();

  static const String none = 'none';
  static const String cyberpunk = 'cyberpunk';
  static const String garden = 'garden';
  static const String paperink = 'paperink';
  static const String matrix = 'matrix';
  static const String phosphor = 'phosphor';
  static const String crimson = 'crimson';
  static const String minimal = 'default';

  static const List<Map<String, String>> options = [
    {'id': none, 'name': 'None (Clean)'},
    {'id': cyberpunk, 'name': 'Cyberpunk'},
    {'id': garden, 'name': 'Dusk Garden'},
    {'id': paperink, 'name': 'Paper Scroll'},
    {'id': matrix, 'name': 'Matrix'},
    {'id': phosphor, 'name': 'Phosphor'},
    {'id': crimson, 'name': 'Crimson'},
    {'id': minimal, 'name': 'Minimal'},
  ];
}

/// Custom painter for rich themed text backgrounds supporting dynamic multi-line bounds.
class ThemedTagBackgroundPainter extends CustomPainter {
  final String styleId;
  final Color primaryAccent;
  final WiltkeyTokens tokens;

  ThemedTagBackgroundPainter({
    required this.styleId,
    required this.primaryAccent,
    required this.tokens,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (styleId == StoryTextStyles.none) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    switch (styleId) {
      case StoryTextStyles.cyberpunk:
        _paintCyberpunk(canvas, size, rect);
        break;
      case StoryTextStyles.garden:
      case 'dusk_garden':
        _paintDuskGarden(canvas, size, rect);
        break;
      case StoryTextStyles.paperink:
      case 'paper_scroll':
        _paintPaperScroll(canvas, size, rect);
        break;
      case StoryTextStyles.matrix:
        _paintMatrix(canvas, size, rect);
        break;
      case StoryTextStyles.phosphor:
        _paintPhosphor(canvas, size, rect);
        break;
      case StoryTextStyles.crimson:
        _paintCrimson(canvas, size, rect);
        break;
      case StoryTextStyles.minimal:
      default:
        _paintMinimal(canvas, size, rect);
        break;
    }
  }

  void _paintCyberpunk(Canvas canvas, Size size, Rect rect) {
    // 1. Angled chamfered background
    const chamfer = 12.0;
    final path = Path()
      ..moveTo(chamfer, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - chamfer)
      ..lineTo(size.width - chamfer, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, chamfer)
      ..close();

    // Dark obsidian backdrop with subtle glow
    final bgPaint = Paint()
      ..color = const Color(0xEE0A0F1D)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, bgPaint);

    // 2. Glitched neon cyan outer stroke
    final strokePaint = Paint()
      ..color = const Color(0xFF00FFCC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.miter;
    canvas.drawPath(path, strokePaint);

    // 3. Neon Magenta glitch accent ticks
    final magentaPaint = Paint()
      ..color = const Color(0xFFFF00A0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.square;

    // Top-left glitch bracket
    canvas.drawLine(const Offset(-2, 4), const Offset(8, 4), magentaPaint);
    canvas.drawLine(const Offset(4, -2), const Offset(4, 8), magentaPaint);

    // Bottom-right glitch bracket
    canvas.drawLine(Offset(size.width - 8, size.height - 4), Offset(size.width + 2, size.height - 4), magentaPaint);
    canvas.drawLine(Offset(size.width - 4, size.height - 8), Offset(size.width - 4, size.height + 2), magentaPaint);

    // Circuit dots
    final dotPaint = Paint()..color = const Color(0xFF00FFCC)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width - 14, 6), 1.5, dotPaint);
    canvas.drawCircle(Offset(size.width - 20, 6), 1.5, dotPaint);
  }

  void _paintDuskGarden(Canvas canvas, Size size, Rect rect) {
    // 1. Soft rounded organic backdrop
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    final bgPaint = Paint()
      ..color = const Color(0xF20B1A12) // Dark lush moss
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    // 2. Leafy vine green border
    final vinePaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRRect(rrect, vinePaint);

    // 3. Blooming flower petals and leaves on corners
    _drawGardenCorner(canvas, const Offset(6, 6), isTopLeft: true);
    _drawGardenCorner(canvas, Offset(size.width - 6, 6), isTopLeft: false, isTopRight: true);
    _drawGardenCorner(canvas, Offset(6, size.height - 6), isBottomLeft: true);
    _drawGardenCorner(canvas, Offset(size.width - 6, size.height - 6), isBottomRight: true);
  }

  void _drawGardenCorner(
    Canvas canvas,
    Offset pos, {
    bool isTopLeft = false,
    bool isTopRight = false,
    bool isBottomLeft = false,
    bool isBottomRight = false,
  }) {
    final leafPaint = Paint()..color = const Color(0xFF7CC96B)..style = PaintingStyle.fill;
    final petalRose = Paint()..color = const Color(0xFFE8A0BF)..style = PaintingStyle.fill;
    final petalGold = Paint()..color = const Color(0xFFFFB000)..style = PaintingStyle.fill;

    // Little leaf
    canvas.drawOval(Rect.fromCenter(center: pos, width: 7, height: 4), leafPaint);

    // Flower center & petals
    canvas.drawCircle(pos, 2.5, petalRose);
    canvas.drawCircle(pos, 1.2, petalGold);
  }

  void _paintPaperScroll(Canvas canvas, Size size, Rect rect) {
    // 1. Warm washi parchment body
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    final paperPaint = Paint()
      ..color = const Color(0xF62B241C) // Deep warm sepia washi
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, paperPaint);

    // 2. Aged gold / ochre border
    final borderPaint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(rrect, borderPaint);

    // 3. Left rolled scroll cylinder & wooden dowel cap
    final scrollDowelPaint = Paint()
      ..color = const Color(0xFF8B6B4A)
      ..style = PaintingStyle.fill;
    final scrollAccentPaint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Left scroll roll rod
    final leftRod = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, -2, 5, size.height + 4),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(leftRod, scrollDowelPaint);
    canvas.drawRRect(leftRod, scrollAccentPaint);

    // 4. Right curled end accent
    final curlPaint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width - 2, 4), Offset(size.width - 2, size.height - 4), curlPaint);

    // 5. Red Hanko Seal Stamp Mark on bottom right
    final hankoBg = Paint()..color = const Color(0xFFC1121F)..style = PaintingStyle.fill;
    final hankoRect = Rect.fromLTWH(size.width - 12, size.height - 11, 8, 8);
    canvas.drawRRect(RRect.fromRectAndRadius(hankoRect, const Radius.circular(1.5)), hankoBg);
  }

  void _paintMatrix(Canvas canvas, Size size, Rect rect) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    final bgPaint = Paint()..color = const Color(0xF0051108)..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    final greenPaint = Paint()
      ..color = const Color(0xFF00FF66)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rrect, greenPaint);

    // Terminal brackets
    const bLen = 8.0;
    // Top-left
    canvas.drawLine(const Offset(0, bLen), const Offset(0, 0), greenPaint..strokeWidth = 2.5);
    canvas.drawLine(const Offset(0, 0), const Offset(bLen, 0), greenPaint..strokeWidth = 2.5);
    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height - bLen), Offset(size.width, size.height), greenPaint);
    canvas.drawLine(Offset(size.width - bLen, size.height), Offset(size.width, size.height), greenPaint);
  }

  void _paintPhosphor(Canvas canvas, Size size, Rect rect) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    final bgPaint = Paint()..color = const Color(0xF21C1200)..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    final amberPaint = Paint()
      ..color = const Color(0xFFFFB000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRRect(rrect, amberPaint);

    // Corner tick studs
    final tickPaint = Paint()..color = const Color(0xFFFFB000)..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(5, 5), 1.8, tickPaint);
    canvas.drawCircle(Offset(size.width - 5, 5), 1.8, tickPaint);
    canvas.drawCircle(Offset(5, size.height - 5), 1.8, tickPaint);
    canvas.drawCircle(Offset(size.width - 5, size.height - 5), 1.8, tickPaint);
  }

  void _paintCrimson(Canvas canvas, Size size, Rect rect) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    final bgPaint = Paint()..color = const Color(0xF21F0407)..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    final redPaint = Paint()
      ..color = const Color(0xFFFF2A55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRRect(rrect, redPaint);

    // Diamond corners
    final diamondPaint = Paint()..color = const Color(0xFFFF2A55)..style = PaintingStyle.fill;
    _drawDiamond(canvas, const Offset(0, 0), 4, diamondPaint);
    _drawDiamond(canvas, Offset(size.width, 0), 4, diamondPaint);
    _drawDiamond(canvas, Offset(0, size.height), 4, diamondPaint);
    _drawDiamond(canvas, Offset(size.width, size.height), 4, diamondPaint);
  }

  void _drawDiamond(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size, center.dy)
      ..lineTo(center.dx, center.dy + size)
      ..lineTo(center.dx - size, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _paintMinimal(Canvas canvas, Size size, Rect rect) {
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(tokens.radiusControl));
    final bgPaint = Paint()..color = tokens.surface.withValues(alpha: 0.90)..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    final borderPaint = Paint()
      ..color = tokens.action.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant ThemedTagBackgroundPainter oldDelegate) =>
      oldDelegate.styleId != styleId ||
      oldDelegate.primaryAccent != primaryAccent;
}

/// A standalone, responsive themed Story Text Tag widget that handles both
/// live in-place editing in the Story Studio and read-only rendering in Story Viewer.
class ThemedStoryTextTag extends StatelessWidget {
  final String text;
  final String styleId;
  final Color textColor;
  final double fontSize;
  final bool isSelected;
  final bool isEditing;
  final TextEditingController? textController;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final WiltkeyTokens tokens;

  const ThemedStoryTextTag({
    super.key,
    required this.text,
    required this.styleId,
    required this.textColor,
    required this.fontSize,
    required this.tokens,
    this.isSelected = false,
    this.isEditing = false,
    this.textController,
    this.focusNode,
    this.onChanged,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isNone = styleId == StoryTextStyles.none;

    // Padding inside the decoration box
    final EdgeInsets padding = isNone
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
        : (styleId == StoryTextStyles.paperink
            ? const EdgeInsets.fromLTRB(14, 8, 16, 8)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 8));

    Widget contentWidget;
    if (isEditing && textController != null) {
      contentWidget = IntrinsicWidth(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 60, maxWidth: 280),
          child: TextField(
            controller: textController,
            focusNode: focusNode,
            autofocus: true,
            maxLines: null,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              shadows: isNone
                  ? const [
                      Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
                      Shadow(color: Colors.black, blurRadius: 2),
                    ]
                  : null,
            ),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              hintText: 'Type text...',
              hintStyle: TextStyle(color: Colors.white54),
            ),
            onChanged: onChanged,
          ),
        ),
      );
    } else {
      contentWidget = Text(
        text.isEmpty ? 'Tap to edit' : text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: isNone
              ? const [
                  Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
                  Shadow(color: Colors.black, blurRadius: 2),
                ]
              : null,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: isSelected
            ? BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: tokens.action.withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              )
            : null,
        child: CustomPaint(
          painter: ThemedTagBackgroundPainter(
            styleId: styleId,
            primaryAccent: tokens.action,
            tokens: tokens,
          ),
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(child: contentWidget),
                if (isSelected && onDelete != null && !isEditing) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white70),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
