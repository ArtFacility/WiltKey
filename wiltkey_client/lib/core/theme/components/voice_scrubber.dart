import 'dart:math';
import 'package:flutter/material.dart';
import '../wk.dart';

/// The shared, token-driven default voice scrubber every theme uses until it
/// ships a bespoke [WiltkeyComponents.voiceScrubber] override (see THEMING.md
/// §3.2). A seeded pseudo-waveform of bars: the portion behind the playhead is
/// drawn in the accent, ahead of it faded. Tap/drag anywhere seeks.
///
/// The shared, token-driven default voice scrubber every theme uses until it
/// ships a bespoke [WiltkeyComponents.voiceScrubber] override (see THEMING.md
/// §3.2). A waveform of bars: the portion behind the playhead is
/// drawn in the accent, ahead of it faded. Tap/drag anywhere seeks.
///
/// If [waveform] is present (from VoiceHeader v2), the bars render real captured
/// audio amplitudes. If omitted or empty, falls back to a stable seeded pseudo-waveform.
class DefaultVoiceScrubber extends StatelessWidget {
  /// Playhead position, 0..1.
  final double progress;
  final bool isPlaying;

  /// Stable per-message seed (used as fallback when waveform is absent).
  final int seed;

  /// Real captured amplitude waveform (0..255 byte samples).
  final List<int>? waveform;

  /// Called with a 0..1 fraction on tap/drag; null disables seeking.
  final ValueChanged<double>? onSeek;
  final Color? accent;

  const DefaultVoiceScrubber({
    super.key,
    required this.progress,
    required this.isPlaying,
    this.seed = 0,
    this.waveform,
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
                waveform: waveform,
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
  final List<int>? waveform;
  final Color playedColor;
  final Color unplayedColor;

  _WavePainter({
    required this.progress,
    required this.seed,
    this.waveform,
    required this.playedColor,
    required this.unplayedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barW = 3.0;
    const gap = 2.0;
    final count = (size.width / (barW + gap)).floor().clamp(1, 200);
    final playedBars = (count * progress).round();
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barW;
    final cy = size.height / 2;
    final bool hasWaveform = waveform != null && waveform!.isNotEmpty;
    final rnd = hasWaveform ? null : Random(seed);

    for (int i = 0; i < count; i++) {
      double normHeight;
      if (hasWaveform) {
        final idx = ((i / count) * waveform!.length).floor().clamp(0, waveform!.length - 1);
        final val = waveform![idx]; // 0..255
        normHeight = 0.15 + (val / 255.0) * 0.80;
      } else {
        normHeight = 0.22 + rnd!.nextDouble() * 0.78;
      }
      final h = normHeight * size.height;
      final x = i * (barW + gap) + barW / 2;
      paint.color = i < playedBars ? playedColor : unplayedColor;
      canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.progress != progress ||
      old.seed != seed ||
      old.waveform != waveform ||
      old.playedColor != playedColor ||
      old.unplayedColor != unplayedColor;
}
