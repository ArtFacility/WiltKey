import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../wk.dart';

/// Cyberpunk nuke (self-destruct) overlay: a data-corruption glitch — flickering
/// scanline/RGB-split bars, a "DATA PURGED" alarm readout — collapsing to an
/// opaque wiped frame. Absorbs input while it plays; calls [onDone] at the end
/// (the caller performs the actual wipe + navigation and removes the entry).
/// Reduce-motion: a quick fade to black.
class CyberpunkNukePurge extends StatefulWidget {
  final VoidCallback onDone;
  const CyberpunkNukePurge({super.key, required this.onDone});

  @override
  State<CyberpunkNukePurge> createState() => _CyberpunkNukePurgeState();
}

class _CyberpunkNukePurgeState extends State<CyberpunkNukePurge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _c.duration = context.reduceMotion
          ? const Duration(milliseconds: 400)
          : const Duration(milliseconds: 1300);
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final p = _c.value;
          final textIn = reduceMotion
              ? 0.0
              : ((p - 0.25) / 0.15).clamp(0.0, 1.0);
          // Alarm text jitters while the glitch rages, then holds.
          final jitter = (p < 0.75 && !reduceMotion)
              ? (math.Random((p * 90).floor()).nextDouble() - 0.5) * 6
              : 0.0;
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _GlitchPainter(
                  p: p,
                  reduceMotion: reduceMotion,
                  danger: t.danger,
                  accent: t.action,
                  dark: t.bg,
                ),
              ),
              Align(
                alignment: const Alignment(0, -0.05),
                child: Opacity(
                  opacity: textIn,
                  child: Transform.translate(
                    offset: Offset(jitter, 0),
                    child: Text(
                      t.uppercaseLabels ? 'DATA PURGED' : 'Data purged',
                      style: t.dataMono.copyWith(
                        color: t.danger,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        shadows: [
                          Shadow(color: t.danger, blurRadius: 12),
                          Shadow(
                            color: t.action.withValues(alpha: 0.5),
                            blurRadius: 20,
                          ),
                        ],
                      ),
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

class _GlitchPainter extends CustomPainter {
  final double p;
  final bool reduceMotion;
  final Color danger, accent, dark;

  _GlitchPainter({
    required this.p,
    required this.reduceMotion,
    required this.danger,
    required this.accent,
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Darkening backdrop that ends fully opaque (the wipe).
    final bgAlpha = reduceMotion
        ? p
        : (0.25 + 0.75 * Curves.easeIn.transform(p));
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark.withValues(alpha: bgAlpha.clamp(0.0, 1.0)),
    );

    if (reduceMotion) return;

    // Corruption bars: random horizontal slabs flickering in alarm colours, more
    // frequent as the purge intensifies.
    final rnd = math.Random((p * 60).floor() * 7 + 13);
    final count = (6 + 26 * p).round();
    final intensity = (1 - p) * 0.9; // fade out as the dark backdrop takes over
    for (int i = 0; i < count; i++) {
      final y = rnd.nextDouble() * size.height;
      final h = 1.5 + rnd.nextDouble() * (6 + 18 * p);
      final w = size.width * (0.2 + rnd.nextDouble() * 0.8);
      final x = rnd.nextDouble() * (size.width - w);
      final useDanger = rnd.nextDouble() < 0.6;
      final a = intensity * (0.15 + rnd.nextDouble() * 0.35);
      canvas.drawRect(
        Rect.fromLTWH(x, y, w, h),
        Paint()
          ..color = (useDanger ? danger : accent).withValues(
            alpha: a.clamp(0.0, 1.0),
          ),
      );
    }

    // A couple of brighter RGB-split slices for the glitch signature.
    for (int i = 0; i < 2; i++) {
      final y = rnd.nextDouble() * size.height;
      final h = 2.0 + rnd.nextDouble() * 4;
      final dx = (rnd.nextDouble() - 0.5) * 18;
      canvas.drawRect(
        Rect.fromLTWH(dx, y, size.width, h),
        Paint()..color = danger.withValues(alpha: 0.25 * intensity),
      );
      canvas.drawRect(
        Rect.fromLTWH(-dx, y + 2, size.width, h),
        Paint()..color = accent.withValues(alpha: 0.25 * intensity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlitchPainter old) => old.p != p;
}
