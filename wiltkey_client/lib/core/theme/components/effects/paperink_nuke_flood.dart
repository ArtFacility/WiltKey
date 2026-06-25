import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../wk.dart';

/// Paper & Ink nuke (self-destruct) overlay: a spilled inkwell. A hard sumi
/// strike hits the top of the screen, then a sheet of black ink floods downward
/// with dripping tendrils and runs, capillary-bleeding into the paper ahead of
/// itself, until the whole screen is opaque sumi — drowned, unrecoverable.
///
/// Absorbs input while it plays and calls [onDone] at the end (the caller then
/// performs the real wipe + navigation and removes the entry). Ends on an opaque
/// frame. Reduce-motion: a quick fade to black, no strike/drips. Token-driven —
/// the ink is `textPrimary` (sumi); no hardcoded colors.
class PaperinkNukeFlood extends StatefulWidget {
  final VoidCallback onDone;
  const PaperinkNukeFlood({super.key, required this.onDone});

  @override
  State<PaperinkNukeFlood> createState() => _PaperinkNukeFloodState();
}

class _PaperinkNukeFloodState extends State<PaperinkNukeFlood>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  // Timeline (fractions of the controller): the ink flood fills the screen over
  // the first part, then we hold on full black while the caption brushes on
  // character-by-character, then a short beat before onDone.
  static const double _floodEnd = 0.56; // screen is fully black by here
  static const double _captionStart = 0.6;
  static const double _captionEnd = 0.88; // then hold 0.88→1.0

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2700),
    );
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _c.duration = context.reduceMotion
          ? const Duration(milliseconds: 800)
          : const Duration(milliseconds: 2700);
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
    final caption = t.uppercaseLabels ? 'DROWNED IN INK' : 'Wiped';
    final chars = caption.split('');
    final captionStyle = t.bodySecondary.copyWith(
      color: t.bgRaised.withValues(alpha: 0.78),
      letterSpacing: 2,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final p = _c.value;
          // Flood plays over [0, _floodEnd]; remap so the painter still runs its
          // full strike→flood→opaque arc within that window.
          final floodP = (p / _floodEnd).clamp(0.0, 1.0);
          final revealT = reduceMotion
              ? (p >= _captionStart ? 1.0 : 0.0)
              : ((p - _captionStart) / (_captionEnd - _captionStart)).clamp(
                  0.0,
                  1.0,
                );
          final shown = revealT * chars.length;

          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _FloodPainter(
                  p: floodP,
                  reduceMotion: reduceMotion,
                  ink: t.textPrimary,
                ),
              ),
              if (shown > 0)
                Align(
                  alignment: const Alignment(0, 0.6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < chars.length; i++)
                        Opacity(
                          opacity: (shown - i).clamp(0.0, 1.0),
                          child: Text(
                            chars[i] == ' ' ? ' ' : chars[i],
                            style: captionStyle,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FloodPainter extends CustomPainter {
  final double p;
  final bool reduceMotion;
  final Color ink;

  // Deterministic drips (tongues hanging off the flood front) and runs (thin
  // streaks racing ahead down the paper).
  static const int _drips = 11;
  static final List<_Drip> _drip = List.generate(_drips, (i) {
    final r = math.Random(i * 71 + 5);
    return _Drip(
      x: (i + 0.5) / _drips + (r.nextDouble() - 0.5) * 0.04,
      w: 10.0 + r.nextDouble() * 26.0,
      len: 0.10 + r.nextDouble() * 0.20, // fraction of height
      lead: r.nextDouble() * 0.12, // starts a touch before the front arrives
    );
  });
  static const int _runs = 7;
  static final List<_Run> _run = List.generate(_runs, (i) {
    final r = math.Random(i * 131 + 17);
    return _Run(
      x: r.nextDouble(),
      w: 1.4 + r.nextDouble() * 2.4,
      len: 0.18 + r.nextDouble() * 0.26,
      start: 0.06 + r.nextDouble() * 0.18,
    );
  });

  _FloodPainter({
    required this.p,
    required this.reduceMotion,
    required this.ink,
  });

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void paint(Canvas canvas, Size size) {
    final inkPaint = Paint()..color = ink;

    // Reduce-motion: a plain quick fade to opaque sumi.
    if (reduceMotion) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = ink.withValues(alpha: p),
      );
      return;
    }

    final w = size.width;
    final h = size.height;

    // 1) The strike — a hard ink spatter where the inkwell hits, top-centre.
    if (p < 0.32) {
      final st = (p / 0.32);
      final fade = (1 - st);
      final origin = Offset(w * 0.5, h * 0.06);
      canvas.drawCircle(
        origin,
        10 + 26 * st,
        Paint()..color = ink.withValues(alpha: 0.5 * fade),
      );
      final r = math.Random(3);
      for (int i = 0; i < 16; i++) {
        final a = r.nextDouble() * 2 * math.pi;
        final d = (20 + r.nextDouble() * 90) * st;
        canvas.drawCircle(
          origin + Offset(math.cos(a), math.sin(a) * 0.7) * d,
          (1.5 + r.nextDouble() * 3.5) * fade,
          Paint()..color = ink.withValues(alpha: 0.85 * fade),
        );
      }
    }

    // 2) The flood front sweeps down (accelerating, like poured ink).
    final front = Curves.easeIn.transform((p / 0.9).clamp(0.0, 1.0));
    const dripMax = 0.34; // max drip reach as fraction of height (overshoot)
    final frontY = _lerp(-h * dripMax, h * (1 + dripMax), front);

    // Covered region: solid above a slightly wavy front edge.
    final cover = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, frontY);
    for (double x = w; x >= 0; x -= 12) {
      final wob = math.sin(x / w * math.pi * 3 + 1.3) * 5.0;
      cover.lineTo(x, frontY + wob);
    }
    cover.close();
    canvas.drawPath(cover, inkPaint);

    // Capillary bleed: ink soaking into the paper just ahead of the front.
    if (frontY > 0 && frontY < h) {
      final bleed = Rect.fromLTWH(0, frontY - 2, w, 34);
      canvas.drawRect(
        bleed,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ink.withValues(alpha: 0.55), ink.withValues(alpha: 0.0)],
          ).createShader(bleed),
      );
    }

    // 3) Drips: rounded tongues hanging off the front.
    for (final d in _drip) {
      final reach = ((front + d.lead) / (1 + d.lead)).clamp(0.0, 1.0);
      final tongue = d.len * h * Curves.easeIn.transform(reach);
      final topY = frontY - 4;
      if (topY > h) continue;
      final cx = d.x * w;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - d.w / 2, topY - d.w, d.w, d.w + tongue),
        Radius.circular(d.w / 2),
      );
      canvas.drawRRect(rect, inkPaint);
      // a bead at the tip
      canvas.drawCircle(Offset(cx, topY + tongue), d.w * 0.32, inkPaint);
    }

    // 4) Runs: thin streaks racing ahead, dragging the UI down with them.
    for (final rn in _run) {
      if (p < rn.start) continue;
      final rp = ((p - rn.start) / (0.92 - rn.start)).clamp(0.0, 1.0);
      final y0 = frontY - 8;
      final y1 = y0 + rn.len * h * Curves.easeIn.transform(rp);
      if (y0 > h) continue;
      final x = rn.x * w;
      canvas.drawLine(
        Offset(x, y0),
        Offset(x, y1),
        Paint()
          ..color = ink.withValues(alpha: 0.8)
          ..strokeWidth = rn.w
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        Offset(x, y1),
        rn.w * 0.9,
        Paint()..color = ink.withValues(alpha: 0.8),
      );
    }

    // 5) Guarantee a fully opaque finish.
    final settle = ((p - 0.9) / 0.1).clamp(0.0, 1.0);
    if (settle > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = ink.withValues(alpha: settle),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FloodPainter old) =>
      old.p != p || old.ink != ink;
}

class _Drip {
  final double x, w, len, lead;
  const _Drip({
    required this.x,
    required this.w,
    required this.len,
    required this.lead,
  });
}

class _Run {
  final double x, w, len, start;
  const _Run({
    required this.x,
    required this.w,
    required this.len,
    required this.start,
  });
}
