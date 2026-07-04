import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../wk.dart';

/// Cyberpunk voice-note scrubber: a seeded soundwave that lights up as it
/// plays. Bars behind the playhead are bright accent with the theme's neon
/// bloom; bars ahead sit at low alpha. A thin playhead line tracks the
/// position and, while playing, the bars just behind it shimmer. Tap/drag
/// anywhere seeks. Reduce-motion: no shimmer — the static played/unplayed
/// split still reads as a progress bar.
class CyberpunkVoicePlayback extends StatefulWidget {
  /// Playhead position, 0..1.
  final double progress;
  final bool isPlaying;

  /// Stable per-message seed (the bubble passes the message id's hash).
  final int seed;

  /// Called with a 0..1 fraction on tap/drag; null disables seeking.
  final ValueChanged<double>? onSeek;
  final Color? accent;

  const CyberpunkVoicePlayback({
    super.key,
    required this.progress,
    required this.isPlaying,
    this.seed = 0,
    this.onSeek,
    this.accent,
  });

  @override
  State<CyberpunkVoicePlayback> createState() => _CyberpunkVoicePlaybackState();
}

class _CyberpunkVoicePlaybackState extends State<CyberpunkVoicePlayback>
    with SingleTickerProviderStateMixin {
  final Stopwatch _clock = Stopwatch()..start();
  AnimationController? _ticker; // repaint pacer while playing; time from _clock
  double _displayed = 0;
  int _lastMs = 0;

  @override
  void initState() {
    super.initState();
    _displayed = widget.progress.clamp(0.0, 1.0);
  }

  void _syncTicker() {
    final wantMotion = widget.isPlaying && !context.reduceMotion;
    if (wantMotion && _ticker == null) {
      _lastMs = _clock.elapsedMilliseconds;
      _ticker = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1),
      )..repeat();
    } else if (!wantMotion && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant CyberpunkVoicePlayback old) {
    super.didUpdateWidget(old);
    if (old.isPlaying != widget.isPlaying) _syncTicker();
    // Not animating (paused / reduce-motion): track the target directly so
    // seeks and position updates still move the bar.
    if (_ticker == null) _displayed = widget.progress.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  /// Frame-rate-independent easing of the displayed playhead toward the real
  /// position (the player's stream updates in chunks). A large jump (a seek)
  /// snaps so scrubbing feels immediate.
  void _step() {
    final target = widget.progress.clamp(0.0, 1.0);
    if (_ticker == null) {
      _displayed = target;
      return;
    }
    final now = _clock.elapsedMilliseconds;
    final dt = ((now - _lastMs).clamp(0, 64)) / 1000.0;
    _lastMs = now;
    if ((target - _displayed).abs() > 0.2) {
      _displayed = target;
    } else {
      _displayed += (target - _displayed) * (1 - math.exp(-dt * 10.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final color = widget.accent ?? t.action;
    final glow = t.glow(color);

    Widget paint() {
      _step();
      return CustomPaint(
        painter: _CyberWavePainter(
          progress: _displayed,
          timeMs: _ticker == null ? -1 : _clock.elapsedMilliseconds,
          seed: widget.seed,
          played: color,
          unplayed: color.withValues(alpha: 0.24),
          glowColor: glow.isEmpty ? null : glow.first.color,
          glowBlur: glow.isEmpty ? 0.0 : glow.first.blurRadius,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        void seekTo(Offset local) {
          if (widget.onSeek == null || constraints.maxWidth <= 0) return;
          widget.onSeek!((local.dx / constraints.maxWidth).clamp(0.0, 1.0));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seekTo(d.localPosition),
          onHorizontalDragUpdate: (d) => seekTo(d.localPosition),
          child: SizedBox(
            height: 30,
            width: double.infinity,
            child: _ticker == null
                ? paint()
                : AnimatedBuilder(
                    animation: _ticker!,
                    builder: (context, _) => paint(),
                  ),
          ),
        );
      },
    );
  }
}

class _CyberWavePainter extends CustomPainter {
  final double progress;
  final int timeMs; // -1 = static (paused / reduce-motion)
  final int seed;
  final Color played;
  final Color unplayed;
  final Color? glowColor; // null = the theme's glow() is empty
  final double glowBlur;

  _CyberWavePainter({
    required this.progress,
    required this.timeMs,
    required this.seed,
    required this.played,
    required this.unplayed,
    required this.glowColor,
    required this.glowBlur,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barW = 3.0;
    const gap = 2.0;
    final count = (size.width / (barW + gap)).floor().clamp(1, 200);
    final rnd = math.Random(seed); // stable geometry per message
    final heights = List.generate(
      count,
      (_) => (0.22 + rnd.nextDouble() * 0.78) * size.height,
    );
    final cy = size.height / 2;
    final playheadX = size.width * progress;

    // Neon bloom under the played bars ("no glow" themes pass glowColor null).
    if (glowColor != null && glowBlur > 0) {
      final bloom = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = barW + 1
        ..color = glowColor!
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlur * 0.6);
      for (int i = 0; i < count; i++) {
        final x = i * (barW + gap) + barW / 2;
        if (x > playheadX) break;
        final h = heights[i];
        canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), bloom);
      }
    }

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barW;
    for (int i = 0; i < count; i++) {
      final x = i * (barW + gap) + barW / 2;
      final h = heights[i];
      var color = x <= playheadX ? played : unplayed;
      // A subtle shimmer on the few bars leading up to the playhead.
      if (timeMs >= 0 && x <= playheadX) {
        final lead = (playheadX - x) / (4 * (barW + gap));
        if (lead < 1.0) {
          final tw = 0.5 + 0.5 * math.sin(timeMs / 90.0 - i * 1.1);
          color = Color.lerp(color, unplayed, 0.35 * tw * (1 - lead))!;
        }
      }
      paint.color = color;
      canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), paint);
    }

    // Thin bright playhead line (only meaningful mid-track).
    if (progress > 0.001 && progress < 0.999) {
      canvas.drawLine(
        Offset(playheadX, 0),
        Offset(playheadX, size.height),
        Paint()
          ..strokeWidth = 1.2
          ..color = played.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CyberWavePainter old) =>
      old.progress != progress ||
      old.timeMs != timeMs ||
      old.seed != seed ||
      old.played != played ||
      old.unplayed != unplayed ||
      old.glowColor != glowColor;
}
