import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../wk.dart';

/// Garden nuke (self-destruct) overlay: the screen washes to a dead brown while a
/// flower drains to grey and its petals detach and fall away, ending on an opaque
/// wiped frame. Absorbs input while it plays; calls [onDone] at the end (the
/// caller then performs the actual wipe + navigation and removes the entry).
/// Reduce-motion: a quick brown-out, no petal fall.
class GardenNukeWilt extends StatefulWidget {
  final VoidCallback onDone;
  const GardenNukeWilt({super.key, required this.onDone});

  @override
  State<GardenNukeWilt> createState() => _GardenNukeWiltState();
}

class _GardenNukeWiltState extends State<GardenNukeWilt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _c.duration = context.reduceMotion
          ? const Duration(milliseconds: 450)
          : const Duration(milliseconds: 1500);
      _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final reduceMotion = context.reduceMotion;
    // A dead, muddy brown derived from tokens (amber → ash), darkening to soil.
    final brown = Color.lerp(t.warning, t.budgetWilted, 0.45)!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final p = _c.value;
          final captionIn = ((p - 0.5) / 0.25).clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _WiltPainter(
                  p: p,
                  reduceMotion: reduceMotion,
                  live: t.budgetFill,
                  dead: t.budgetWilted,
                  center: t.surfacePressed,
                  brown: brown,
                  dark: t.bg,
                ),
              ),
              Align(
                alignment: const Alignment(0, 0.55),
                child: Opacity(
                  opacity: captionIn,
                  child: Text(
                    t.uppercaseLabels ? 'MEMORY WIPED' : 'Wiped',
                    style: t.bodySecondary.copyWith(
                      color: t.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WiltPainter extends CustomPainter {
  final double p;
  final bool reduceMotion;
  final Color live, dead, center, brown, dark;

  static const int _petals = 8;
  static final List<double> _drift = List.generate(
    _petals,
    (i) => (i.isEven ? 1 : -1) * (0.4 + (i * 0.23) % 0.6),
  );
  static final List<double> _spin = List.generate(
    _petals,
    (i) => (i.isEven ? 1 : -1) * (1.5 + (i * 0.37) % 1.2),
  );

  _WiltPainter({
    required this.p,
    required this.reduceMotion,
    required this.live,
    required this.dead,
    required this.center,
    required this.brown,
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final unit = math.min(size.width, size.height);
    final flowerR = unit * 0.14;
    final petalLen = flowerR * 0.72;
    final petalW = flowerR * 0.40;

    // Colour drains from marigold to ash.
    final drain = ((p - 0.18) / 0.30).clamp(0.0, 1.0);
    final petalColor = Color.lerp(live, dead, drain)!;
    final fallDist = size.height * 0.55;

    for (int i = 0; i < _petals; i++) {
      final ang = (i / _petals) * 2 * math.pi - math.pi / 2;
      final detach = 0.40 + i * 0.035;
      final fp = reduceMotion ? 0.0 : ((p - detach) / 0.40).clamp(0.0, 1.0);

      // Rest position of the petal.
      final baseX = c.dx + math.cos(ang) * petalLen * 0.55;
      final baseY = c.dy + math.sin(ang) * petalLen * 0.55;
      // Falling adds gravity drop + drift + spin + fade.
      final fall = Curves.easeIn.transform(fp);
      final px = baseX + _drift[i] * flowerR * fp;
      final py = baseY + fall * fallDist;
      final rot = ang + _spin[i] * fp;
      final alpha = (1 - fp);
      if (alpha <= 0) continue;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rot);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: petalLen, height: petalW),
        Paint()..color = petalColor.withValues(alpha: alpha),
      );
      canvas.restore();
    }

    // The dimming centre.
    final centerFade = (1 - ((p - 0.55) / 0.30).clamp(0.0, 1.0));
    if (centerFade > 0) {
      canvas.drawCircle(
        c,
        flowerR * 0.30,
        Paint()
          ..color = Color.lerp(
            center,
            dead,
            drain,
          )!.withValues(alpha: centerFade),
      );
    }

    // Brown wash creeping over everything, then darkening to soil (ends opaque).
    final washAlpha = p < 0.6
        ? (p / 0.6) * 0.55
        : (0.55 + ((p - 0.6) / 0.4) * 0.45);
    final washColor = Color.lerp(
      brown,
      dark,
      ((p - 0.6) / 0.4).clamp(0.0, 1.0),
    )!;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = washColor.withValues(alpha: washAlpha.clamp(0.0, 1.0)),
    );
  }

  @override
  bool shouldRepaint(covariant _WiltPainter old) => old.p != p;
}
