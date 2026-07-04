import 'dart:math';
import 'package:flutter/material.dart';
import '../wk.dart';

/// The shared, token-driven default voice scrubber every theme uses until it
/// ships a bespoke [WiltkeyComponents.voiceScrubber] override (see THEMING.md
/// §3.2). A seeded pseudo-waveform of bars: the portion behind the playhead is
/// drawn in the accent, ahead of it faded. Tap/drag anywhere seeks.
///
/// The bar geometry is seeded (stable across rebuilds and identical on both
/// peers for the same message), not derived from the real audio — decoding just
/// to draw bars isn't worth it for v1.
class DefaultVoiceScrubber extends StatelessWidget {
  /// Playhead position, 0..1.
  final double progress;
  final bool isPlaying;

  /// Stable per-message seed (the bubble passes the message id's hash).
  final int seed;

  /// Called with a 0..1 fraction on tap/drag; null disables seeking.
  final ValueChanged<double>? onSeek;
  final Color? accent;

  const DefaultVoiceScrubber({
    super.key,
    required this.progress,
    required this.isPlaying,
    this.seed = 0,
    this.onSeek,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final color = accent ?? t.action;
    return LayoutBuilder(
      builder: (context, constraints) {
        void seekTo(Offset local) {
          if (onSeek == null || constraints.maxWidth <= 0) return;
          onSeek!((local.dx / constraints.maxWidth).clamp(0.0, 1.0));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seekTo(d.localPosition),
          onHorizontalDragUpdate: (d) => seekTo(d.localPosition),
          child: SizedBox(
            height: 30,
            width: double.infinity,
            child: CustomPaint(
              painter: _WavePainter(
                progress: progress.clamp(0.0, 1.0),
                seed: seed,
                playedColor: color,
                unplayedColor: color.withValues(alpha: 0.28),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final int seed;
  final Color playedColor;
  final Color unplayedColor;

  _WavePainter({
    required this.progress,
    required this.seed,
    required this.playedColor,
    required this.unplayedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barW = 3.0;
    const gap = 2.0;
    final count = (size.width / (barW + gap)).floor().clamp(1, 200);
    final rnd = Random(seed); // stable geometry per message
    final playedBars = (count * progress).round();
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barW;
    final cy = size.height / 2;
    for (int i = 0; i < count; i++) {
      final h = (0.22 + rnd.nextDouble() * 0.78) * size.height;
      final x = i * (barW + gap) + barW / 2;
      paint.color = i < playedBars ? playedColor : unplayedColor;
      canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.progress != progress ||
      old.seed != seed ||
      old.playedColor != playedColor ||
      old.unplayedColor != unplayedColor;
}
