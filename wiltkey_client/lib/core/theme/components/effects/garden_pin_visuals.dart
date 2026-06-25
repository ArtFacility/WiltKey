import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../wk.dart';

/// Garden PIN entry readout: a small flower that grows one petal per entered
/// digit (a full bloom at the last digit). The newest petal pops in; a failed
/// attempt tints the bloom red. Reduce-motion: petals appear instantly.
class GardenPinProgress extends StatefulWidget {
  final int entered;
  final int length;
  final bool error;

  const GardenPinProgress({
    super.key,
    required this.entered,
    required this.length,
    required this.error,
  });

  @override
  State<GardenPinProgress> createState() => _GardenPinProgressState();
}

class _GardenPinProgressState extends State<GardenPinProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant GardenPinProgress old) {
    super.didUpdateWidget(old);
    if (widget.entered > old.entered && !context.reduceMotion) {
      _pop.forward(from: 0);
    } else if (widget.entered != old.entered) {
      _pop.value = 1;
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  static double _easeOutBack(double t) {
    const c = 2.0;
    final u = t - 1;
    return 1 + (c + 1) * u * u * u + c * u * u;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return SizedBox(
      width: 56,
      height: 56,
      child: AnimatedBuilder(
        animation: _pop,
        builder: (_, _) => CustomPaint(
          painter: _PinFlowerPainter(
            entered: widget.entered,
            length: widget.length,
            error: widget.error,
            newestPop: _easeOutBack(_pop.value).clamp(0.0, 1.2),
            petal: widget.error ? t.danger : t.budgetFill,
            ghost: t.textTertiary,
            center: t.surfacePressed,
            complete: widget.entered >= widget.length,
            completeColor: t.positive,
          ),
        ),
      ),
    );
  }
}

class _PinFlowerPainter extends CustomPainter {
  final int entered;
  final int length;
  final bool error;
  final double newestPop;
  final Color petal, ghost, center, completeColor;
  final bool complete;

  _PinFlowerPainter({
    required this.entered,
    required this.length,
    required this.error,
    required this.newestPop,
    required this.petal,
    required this.ghost,
    required this.center,
    required this.complete,
    required this.completeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.5;
    final petalLen = r * 0.62;
    final petalW = r * 0.34;

    for (int i = 0; i < length; i++) {
      final ang = (i / length) * 2 * math.pi - math.pi / 2;
      final filled = i < entered;
      final isNewest = i == entered - 1;
      final scale = filled ? (isNewest ? newestPop : 1.0) : 1.0;
      final pl = petalLen * scale;
      final pw = petalW * scale;
      canvas.save();
      canvas.translate(
        c.dx + math.cos(ang) * petalLen * 0.55,
        c.dy + math.sin(ang) * petalLen * 0.55,
      );
      canvas.rotate(ang);
      if (filled) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: pl, height: pw),
          Paint()..color = petal,
        );
      } else {
        // Ghost slot for an un-entered digit.
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: petalLen, height: petalW),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = ghost.withValues(alpha: 0.35),
        );
      }
      canvas.restore();
    }

    final cr = r * 0.26;
    canvas.drawCircle(c, cr, Paint()..color = center);
    canvas.drawCircle(
      c,
      cr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = (complete ? completeColor : Color.lerp(petal, center, 0.3)!),
    );
  }

  @override
  bool shouldRepaint(covariant _PinFlowerPainter old) =>
      old.entered != entered ||
      old.error != error ||
      old.newestPop != newestPop ||
      old.complete != complete;
}

/// Garden unlock transition: a full-screen overlay that blooms a flower, holds
/// briefly, then cross-fades out to reveal the app beneath. Calls [onDone] when
/// finished (the caller removes the overlay entry). Reduce-motion: a short fade.
class GardenUnlockBloom extends StatefulWidget {
  final VoidCallback onDone;
  const GardenUnlockBloom({super.key, required this.onDone});

  @override
  State<GardenUnlockBloom> createState() => _GardenUnlockBloomState();
}

class _GardenUnlockBloomState extends State<GardenUnlockBloom>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    // Reduce-motion still needs to clear the overlay — run a short fade.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _c.duration = context.reduceMotion
          ? const Duration(milliseconds: 350)
          : const Duration(milliseconds: 1150);
      _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _easeOutBack(double t) {
    const k = 1.70158;
    final u = t - 1;
    return 1 + (k + 1) * u * u * u + k * u * u;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final reduceMotion = context.reduceMotion;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final v = _c.value;
          // Phase 1: bloom (0..0.5). Phase 2: fade the whole overlay out (0.6..1).
          final bloom = reduceMotion ? 1.0 : (v / 0.5).clamp(0.0, 1.0);
          final fade = v < 0.6
              ? 1.0
              : (1.0 - ((v - 0.6) / 0.4)).clamp(0.0, 1.0);
          return Opacity(
            opacity: fade,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [t.bgRaised, t.bg],
                ),
              ),
              child: CustomPaint(
                size: Size.infinite,
                painter: _UnlockBloomPainter(
                  bloom: _easeOutBack(bloom).clamp(0.0, 1.2),
                  raw: bloom,
                  reduceMotion: reduceMotion,
                  petal: t.budgetFill,
                  back: Color.lerp(t.budgetFill, t.surfacePressed, 0.2)!,
                  center: t.surfacePressed,
                  halo: t.action,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UnlockBloomPainter extends CustomPainter {
  final double bloom; // eased
  final double raw; // linear 0..1
  final bool reduceMotion;
  final Color petal, back, center, halo;

  static const int _burst = 14;
  static final List<double> _ang = List.generate(
    _burst,
    (i) => i * (2 * math.pi / _burst) + (i.isEven ? 0.2 : -0.1),
  );
  static final List<double> _spd = List.generate(
    _burst,
    (i) => 0.8 + ((i * 0.41) % 1.0) * 0.5,
  );

  _UnlockBloomPainter({
    required this.bloom,
    required this.raw,
    required this.reduceMotion,
    required this.petal,
    required this.back,
    required this.center,
    required this.halo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final unit = math.min(size.width, size.height);

    // Pollen halo.
    if (!reduceMotion && raw > 0) {
      canvas.drawCircle(
        c,
        unit * (0.10 + 0.18 * raw),
        Paint()..color = halo.withValues(alpha: 0.18 * (1 - raw)),
      );
    }

    // Petal burst.
    if (!reduceMotion && raw > 0) {
      final dist = unit * (0.10 + 0.22 * Curves.easeOut.transform(raw));
      final a = 1 - raw;
      for (int i = 0; i < _burst; i++) {
        final p =
            c + Offset(math.cos(_ang[i]), math.sin(_ang[i])) * dist * _spd[i];
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(_ang[i]);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: 16 * a + 4,
            height: 7 * a + 2,
          ),
          Paint()..color = petal.withValues(alpha: 0.8 * a),
        );
        canvas.restore();
      }
    }

    // Central flower — two rings.
    final s = bloom;
    for (final ring in [
      (count: 8, len: unit * 0.16, w: unit * 0.082, off: 0.0, isBack: true),
      (
        count: 8,
        len: unit * 0.125,
        w: unit * 0.07,
        off: math.pi / 8,
        isBack: false,
      ),
    ]) {
      final pl = ring.len * s;
      final pw = ring.w * s;
      for (int i = 0; i < ring.count; i++) {
        final ang = (i / ring.count) * 2 * math.pi + ring.off;
        canvas.save();
        canvas.translate(
          c.dx + math.cos(ang) * pl * 0.52,
          c.dy + math.sin(ang) * pl * 0.52,
        );
        canvas.rotate(ang);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: pl, height: pw),
          Paint()..color = ring.isBack ? back : petal,
        );
        canvas.restore();
      }
    }
    final cr = unit * 0.06 * raw;
    canvas.drawCircle(c, cr, Paint()..color = center);
  }

  @override
  bool shouldRepaint(covariant _UnlockBloomPainter old) =>
      old.bloom != bloom || old.raw != raw;
}
