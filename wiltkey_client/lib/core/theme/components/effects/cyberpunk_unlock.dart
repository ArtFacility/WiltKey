import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../wk.dart';

/// Cyberpunk unlock transition: a HUD "access granted" sequence — targeting
/// brackets converge and lock on, a crosshair snaps in, a scanline sweeps the
/// frame, and glowing terminal text appears, then the whole overlay fades out to
/// reveal the app. Calls [onDone] when finished (the caller removes the entry).
/// Reduce-motion: a short obsidian fade, no HUD.
class CyberpunkUnlockSequence extends StatefulWidget {
  final VoidCallback onDone;
  const CyberpunkUnlockSequence({super.key, required this.onDone});

  @override
  State<CyberpunkUnlockSequence> createState() =>
      _CyberpunkUnlockSequenceState();
}

class _CyberpunkUnlockSequenceState extends State<CyberpunkUnlockSequence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _c.duration = context.reduceMotion
          ? const Duration(milliseconds: 300)
          : const Duration(milliseconds: 950);
      _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _easeOut(double t) => 1 - math.pow(1 - t, 3).toDouble();

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final reduceMotion = context.reduceMotion;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final v = _c.value;
          // Hold opaque, then fade the overlay out in the last third.
          final fade = v < 0.66
              ? 1.0
              : (1.0 - ((v - 0.66) / 0.34)).clamp(0.0, 1.0);
          final lock = reduceMotion ? 1.0 : _easeOut((v / 0.5).clamp(0.0, 1.0));
          final textIn = reduceMotion
              ? 0.0
              : ((v - 0.34) / 0.18).clamp(0.0, 1.0);

          return Opacity(
            opacity: fade,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: t.bg),
                if (!reduceMotion)
                  CustomPaint(
                    painter: _HudPainter(
                      lock: lock,
                      sweep: v,
                      accent: t.action,
                    ),
                  ),
                if (!reduceMotion)
                  Align(
                    alignment: const Alignment(0, 0.42),
                    child: Opacity(
                      opacity: textIn * fade,
                      child: Text(
                        t.uppercaseLabels ? 'ACCESS GRANTED' : 'Access granted',
                        style: t.dataMono.copyWith(
                          color: t.action,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(color: t.action, blurRadius: 12),
                            Shadow(
                              color: t.action.withValues(alpha: 0.6),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HudPainter extends CustomPainter {
  final double lock; // 0..1 brackets converge + crosshair snaps
  final double sweep; // 0..1 raw timeline, drives the scanline
  final Color accent;

  _HudPainter({required this.lock, required this.sweep, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final unit = math.min(size.width, size.height);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.45 + 0.55 * lock);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.12 * lock)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Targeting brackets converge from wide to a tight box.
    final hs = unit * (0.34 - 0.16 * lock); // half-size of the bracket box
    final bl = unit * 0.06; // bracket arm length
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        final corner = Offset(c.dx + sx * hs, c.dy + sy * hs);
        final h = Path()
          ..moveTo(corner.dx, corner.dy)
          ..lineTo(corner.dx - sx * bl, corner.dy);
        final vv = Path()
          ..moveTo(corner.dx, corner.dy)
          ..lineTo(corner.dx, corner.dy - sy * bl);
        canvas.drawPath(h, glow);
        canvas.drawPath(vv, glow);
        canvas.drawPath(h, stroke);
        canvas.drawPath(vv, stroke);
      }
    }

    // Crosshair snapping in at the centre.
    final ch = unit * 0.05 * lock;
    const gap = 0.0;
    canvas.drawLine(
      Offset(c.dx - ch - gap, c.dy),
      Offset(c.dx - gap, c.dy),
      stroke,
    );
    canvas.drawLine(
      Offset(c.dx + gap, c.dy),
      Offset(c.dx + ch + gap, c.dy),
      stroke,
    );
    canvas.drawLine(
      Offset(c.dx, c.dy - ch - gap),
      Offset(c.dx, c.dy - gap),
      stroke,
    );
    canvas.drawLine(
      Offset(c.dx, c.dy + gap),
      Offset(c.dx, c.dy + ch + gap),
      stroke,
    );

    // Lock-on flash ring as the brackets seat.
    if (lock > 0.6) {
      final f = (lock - 0.6) / 0.4;
      canvas.drawCircle(
        c,
        unit * (0.10 + 0.18 * f),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accent.withValues(alpha: 0.5 * (1 - f)),
      );
    }

    // Single scanline sweeping top→bottom across the whole frame.
    final sy = size.height * Curves.easeInOut.transform(sweep.clamp(0.0, 1.0));
    canvas.drawLine(
      Offset(0, sy),
      Offset(size.width, sy),
      Paint()
        ..color = accent.withValues(alpha: 0.20)
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(covariant _HudPainter old) =>
      old.lock != lock || old.sweep != sweep;
}
