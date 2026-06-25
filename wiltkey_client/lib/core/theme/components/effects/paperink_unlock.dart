import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../wk.dart';

/// Paper & Ink unlock transition — a physical hanko stamp impact sequence.
/// Replicates exactly the HTML reference at documentation/theming/hanko_stamp_animation.html.
class PaperinkUnlockSequence extends StatefulWidget {
  final VoidCallback onDone;
  const PaperinkUnlockSequence({super.key, required this.onDone});

  @override
  State<PaperinkUnlockSequence> createState() => _PaperinkUnlockSequenceState();

  static bool _warmed = false;

  /// Pre-rasterize the heavy first-play resources (the large ShipporiMincho
  /// 枯/鍵 glyphs, the blur shaders) into an offscreen image so the stamp impact
  /// doesn't jank the first time it plays. Cheap, idempotent, runs while the
  /// lock screen is idle. Glyph atlas + shader caches persist app-wide after.
  static void warmUp() {
    if (_warmed) return;
    _warmed = true;
    const red = Color(0xFFC12A23);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, 120, 120));

    for (final ch in const ['枯', '鍵']) {
      final tp = TextPainter(
        text: TextSpan(
          text: ch,
          style: const TextStyle(
            fontFamily: 'ShipporiMincho',
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: red,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, const Offset(20, 20));
      tp.dispose();
    }

    // Blur shader used by the imprint, and a mask-blur like the stamp shadows.
    canvas.saveLayer(
      const Rect.fromLTWH(0, 0, 120, 120),
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 0.4, sigmaY: 0.4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 10, 80, 80),
        const Radius.circular(12),
      ),
      Paint()..color = red,
    );
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 10, 80, 80),
        const Radius.circular(14),
      ),
      Paint()
        ..color = red
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final pic = rec.endRecording();
    // Synchronous rasterization forces glyph-atlas upload + shader compile now.
    final img = pic.toImageSync(120, 120);
    img.dispose();
    pic.dispose();
  }
}

class _PaperinkUnlockSequenceState extends State<PaperinkUnlockSequence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _c.duration = context.reduceMotion
          ? const Duration(milliseconds: 350)
          : const Duration(milliseconds: 1600);
      _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _lerp(double start, double end, double t) {
    return start + (end - start) * t;
  }

  Widget _buildImprintWidget() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC12A23), width: 4),
        gradient: RadialGradient(
          colors: [
            Colors.transparent,
            const Color(0xFFC12A23).withValues(alpha: 0.08),
          ],
          stops: const [0.6, 1.0],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '枯',
              style: TextStyle(
                fontFamily: 'ShipporiMincho',
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFFC12A23),
                height: 1.1,
                letterSpacing: -1.0,
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -4),
              child: const Text(
                '鍵',
                style: TextStyle(
                  fontFamily: 'ShipporiMincho',
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFC12A23),
                  height: 1.1,
                  letterSpacing: -1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStampWidget({required List<BoxShadow> shadows}) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A2A), Color(0xFF111111)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1.0,
        ),
        boxShadow: shadows,
      ),
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(
              0,
              -0.82,
            ), // top-center-ish, top: 8px on 88px tall container
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE5E5E5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final reduceMotion = context.reduceMotion;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;

          // ── Reduce-motion: simple static seal that fades out ──
          if (reduceMotion) {
            final double fade = (1.0 - v).clamp(0.0, 1.0);
            return Opacity(
              opacity: fade,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: t.bg),
                  Center(
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: 0.4,
                        sigmaY: 0.4,
                      ),
                      child: _buildImprintWidget(),
                    ),
                  ),
                ],
              ),
            );
          }

          // Full animation timeline (1600ms):
          // 0.0 -> 0.125: Drop
          // 0.125 -> 0.21875: Squash/Hold (Impact)
          // 0.21875 -> 0.59375: Lift Off
          // 0.59375 -> 0.78125: Ink Bleed (Hold/Settle)
          // 0.78125 -> 1.0: Overlay Fade Out

          // 1. Calculate general opacity of the overlay washi background and imprint
          double bgOpacity = 1.0;
          double imprintOpacity = 0.0;
          double imprintScale = 0.8;
          double imprintRotation = -2.0 * math.pi / 180.0;

          if (v >= 0.125 && v < 0.78125) {
            // imprint transitions on impact in first 50ms (v = 0.125 to 0.15625)
            if (v < 0.15625) {
              final double tImprint = (v - 0.125) / 0.03125;
              imprintOpacity = _lerp(0.0, 0.9, tImprint);
              imprintScale = _lerp(0.8, 1.0, tImprint);
            } else {
              imprintOpacity = 0.9;
              imprintScale = 1.0;
            }
          } else if (v >= 0.78125) {
            final double tFade = (v - 0.78125) / 0.21875;
            final double easedFade = Curves.easeIn.transform(tFade);
            bgOpacity = (1.0 - easedFade).clamp(0.0, 1.0);
            imprintOpacity = 0.9 * bgOpacity;
            imprintScale = 1.0;
          }

          // 2. Calculate screen shake (applied only to target container)
          double shakeX = 0.0;
          double shakeY = 0.0;
          double shakeRot = 0.0;
          if (v >= 0.125 && v <= 0.3125) {
            final double tShake = (v - 0.125) / 0.1875; // 300ms
            if (tShake <= 1.0) {
              final double segmentProgress = (tShake * 5) % 1.0;
              final int segmentIndex = (tShake * 5).floor();
              Offset startOffset;
              Offset endOffset;
              double startRot;
              double endRot;
              switch (segmentIndex) {
                case 0:
                  startOffset = Offset.zero;
                  endOffset = const Offset(-3, 3);
                  startRot = 0.0;
                  endRot = -1.0 * math.pi / 180.0;
                  break;
                case 1:
                  startOffset = const Offset(-3, 3);
                  endOffset = const Offset(3, -2);
                  startRot = -1.0 * math.pi / 180.0;
                  endRot = 1.0 * math.pi / 180.0;
                  break;
                case 2:
                  startOffset = const Offset(3, -2);
                  endOffset = const Offset(-2, -3);
                  startRot = 1.0 * math.pi / 180.0;
                  endRot = 0.0;
                  break;
                case 3:
                  startOffset = const Offset(-2, -3);
                  endOffset = const Offset(2, 2);
                  startRot = 0.0;
                  endRot = 1.0 * math.pi / 180.0;
                  break;
                default:
                  startOffset = const Offset(2, 2);
                  endOffset = Offset.zero;
                  startRot = 1.0 * math.pi / 180.0;
                  endRot = 0.0;
                  break;
              }
              final Offset offset = Offset.lerp(
                startOffset,
                endOffset,
                segmentProgress,
              )!;
              shakeX = offset.dx;
              shakeY = offset.dy;
              shakeRot = _lerp(startRot, endRot, segmentProgress);
            }
          }

          // 3. Calculate stamp properties
          double stampOpacity = 0.0;
          double stampScaleX = 1.0;
          double stampScaleY = 1.0;
          double stampTranslateX = 0.0;
          double stampTranslateY = 0.0;
          double stampRotation = 0.0;
          List<BoxShadow> stampShadows = [];

          if (v < 0.125) {
            // DROP
            final double tD = v / 0.125;
            final double eased = const Cubic(0.5, 0.0, 1.0, 1.0).transform(tD);

            // Opacity fades in over first 100ms (tD = 0.5)
            stampOpacity = (tD * 2.0).clamp(0.0, 1.0);

            final Offset translate = Offset.lerp(
              const Offset(-20, -250),
              Offset.zero,
              eased,
            )!;
            stampTranslateX = translate.dx;
            stampTranslateY = translate.dy;

            final double scale = _lerp(2.5, 1.0, eased);
            stampScaleX = scale;
            stampScaleY = scale;

            stampRotation = _lerp(
              15.0 * math.pi / 180.0,
              -2.0 * math.pi / 180.0,
              eased,
            );

            stampShadows = [
              BoxShadow(
                color: Color.lerp(
                  const Color(0x1A000000),
                  const Color(0x80000000),
                  eased,
                )!,
                offset: Offset.lerp(
                  const Offset(30, 100),
                  const Offset(2, 2),
                  eased,
                )!,
                blurRadius: _lerp(40, 4, eased),
              ),
              BoxShadow(
                color: Color.lerp(
                  const Color(0x0D000000),
                  const Color(0x66000000),
                  eased,
                )!,
                offset: Offset.lerp(const Offset(15, 50), Offset.zero, eased)!,
                blurRadius: _lerp(20, 2, eased),
              ),
            ];
          } else if (v < 0.21875) {
            // SQUASH / HOLD IMPACT
            stampOpacity = 1.0;
            stampRotation = -2.0 * math.pi / 180.0;

            // Squash ease-out (50ms, from 0.125 to 0.15625)
            if (v < 0.15625) {
              final double tS = (v - 0.125) / 0.03125;
              final double easedS = Curves.easeOut.transform(tS);
              stampScaleX = _lerp(1.0, 1.03, easedS);
              stampScaleY = _lerp(1.0, 0.95, easedS);
              stampTranslateY = _lerp(0.0, 3.0, easedS);
            } else {
              // Hold squash
              stampScaleX = 1.03;
              stampScaleY = 0.95;
              stampTranslateY = 3.0;
            }

            stampShadows = [
              const BoxShadow(
                color: Color(0x80000000),
                offset: Offset(2, 2),
                blurRadius: 4,
              ),
              const BoxShadow(
                color: Color(0x66000000),
                offset: Offset.zero,
                blurRadius: 2,
              ),
            ];
          } else if (v < 0.59375) {
            // LIFT OFF
            final double tL = (v - 0.21875) / 0.375;
            final double eased = const Cubic(0.2, 0.8, 0.2, 1.0).transform(tL);

            // Opacity: stays 1.0 for first 200ms (tL = 0.333), then fades to 0.0
            if (tL < 0.333) {
              stampOpacity = 1.0;
            } else {
              final double tFade = (tL - 0.333) / 0.667;
              stampOpacity = (1.0 - Curves.easeIn.transform(tFade)).clamp(
                0.0,
                1.0,
              );
            }

            final Offset translate = Offset.lerp(
              const Offset(0, 3), // starts from squash position
              const Offset(50, -150),
              eased,
            )!;
            stampTranslateX = translate.dx;
            stampTranslateY = translate.dy;

            final Offset scale = Offset.lerp(
              const Offset(1.03, 0.95),
              const Offset(1.4, 1.4),
              eased,
            )!;
            stampScaleX = scale.dx;
            stampScaleY = scale.dy;

            stampRotation = _lerp(
              -2.0 * math.pi / 180.0,
              25.0 * math.pi / 180.0,
              eased,
            );

            stampShadows = [
              BoxShadow(
                color: Color.lerp(
                  const Color(0x80000000),
                  const Color(0x26000000),
                  eased,
                )!,
                offset: Offset.lerp(
                  const Offset(2, 2),
                  const Offset(-20, 50),
                  eased,
                )!,
                blurRadius: _lerp(4, 30, eased),
              ),
              BoxShadow(
                color: Color.lerp(
                  const Color(0x66000000),
                  Colors.transparent,
                  eased,
                )!,
                offset: Offset.lerp(Offset.zero, Offset.zero, eased)!,
                blurRadius: _lerp(2, 0, eased),
              ),
            ];
          }

          return Opacity(
            opacity: bgOpacity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Washi paper background covering the screen
                ColoredBox(color: t.bg),

                // 2. Centered Target Area Card (dashed card)
                Center(
                  child: Transform.translate(
                    offset: Offset(shakeX, shakeY),
                    child: Transform.rotate(
                      angle: shakeRot,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDFDF9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            // Dashed border painter
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _DashedRoundedRectPainter(
                                  color: t.border,
                                  strokeWidth: 2,
                                  radius: 16,
                                  dashLength: 6,
                                  gapLength: 4,
                                ),
                              ),
                            ),

                            // 2a. Red imprint (appears on impact)
                            if (imprintOpacity > 0.0)
                              Opacity(
                                opacity: imprintOpacity,
                                child: Transform.rotate(
                                  angle: imprintRotation,
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..setEntry(0, 0, imprintScale)
                                      ..setEntry(1, 1, imprintScale),
                                    child: ImageFiltered(
                                      imageFilter: ui.ImageFilter.blur(
                                        sigmaX: 0.4,
                                        sigmaY: 0.4,
                                      ),
                                      child: _buildImprintWidget(),
                                    ),
                                  ),
                                ),
                              ),

                            // 2b. Particles painter (draws exploding ink splashes)
                            if (v >= 0.125 && v < 0.3125)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _ParticlesPainter(
                                    v: v,
                                    color: const Color(0xFFC12A23),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Stamp block (rendered on top of card, not clipped by it)
                if (stampOpacity > 0.0)
                  Center(
                    // Align stamp center with card center
                    child: Transform.translate(
                      offset: Offset(stampTranslateX, stampTranslateY),
                      child: Transform.rotate(
                        angle: stampRotation,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(0, 0, stampScaleX)
                            ..setEntry(1, 1, stampScaleY),
                          child: Opacity(
                            opacity: stampOpacity,
                            child: _buildStampWidget(shadows: stampShadows),
                          ),
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

// =============================================================================
// Helper Painters & Data Types
// =============================================================================

class _DashedRoundedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashLength;
  final double gapLength;

  _DashedRoundedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.dashLength,
    required this.gapLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    // Calculate dashed path
    final dashedPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final length = draw ? dashLength : gapLength;
        if (draw) {
          dashedPath.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius;
}

class _ParticleData {
  final double angle;
  final double velocity;
  final double durationFrac;

  const _ParticleData({
    required this.angle,
    required this.velocity,
    required this.durationFrac,
  });
}

// Deterministic list of 15 particles
final List<_ParticleData> _particles = List.generate(15, (index) {
  final double angle = (index / 15.0) * 2.0 * math.pi + (0.1 * (index % 3));
  final double velocity = 25.0 + 8.0 * (index % 5);
  final double durationMs = 300.0 + 40.0 * (index % 6);
  return _ParticleData(
    angle: angle,
    velocity: velocity,
    durationFrac: durationMs / 1600.0,
  );
});

class _ParticlesPainter extends CustomPainter {
  final double v;
  final Color color;

  _ParticlesPainter({required this.v, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (v < 0.125) return;

    final center = size.center(Offset.zero);
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in _particles) {
      final double tP = (v - 0.125) / p.durationFrac;
      if (tP >= 0.0 && tP <= 1.0) {
        // Easing: cubic-bezier(0.2, 0.8, 0.2, 1)
        final double eased = const Cubic(0.2, 0.8, 0.2, 1.0).transform(tP);
        final double tx = math.cos(p.angle) * p.velocity * eased;
        final double ty = math.sin(p.angle) * p.velocity * eased;
        final double scale = 1.0 - eased;

        paint.color = color.withValues(alpha: 1.0 - eased);
        canvas.drawCircle(
          Offset(center.dx + tx, center.dy + ty),
          2.5 * scale,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) =>
      oldDelegate.v != v || oldDelegate.color != color;
}
