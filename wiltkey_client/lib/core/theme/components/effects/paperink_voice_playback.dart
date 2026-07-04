import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../wk.dart';

/// Paper & Ink voice-note scrubber: a handscroll unrolling left→right. The
/// revealed parchment width tracks the playhead, with a small wooden roller at
/// its edge; seeded sumi ink marks are brushed along the opened paper (the
/// freshest ones, just unrolled, fade in as wet ink). Ahead of the roller a
/// faint dashed guide keeps it reading as a progress bar. The accent appears
/// only as a thin baseline under the played stretch, in keeping with the
/// theme's "red = seal" discipline (a group sender's identity tints it).
/// Tap/drag anywhere seeks. Reduce-motion: the scroll is simply shown revealed
/// to the current position — no roll easing, no roller shimmer.
class PaperinkVoicePlayback extends StatefulWidget {
  /// Playhead position, 0..1.
  final double progress;
  final bool isPlaying;

  /// Stable per-message seed (the bubble passes the message id's hash).
  final int seed;

  /// Called with a 0..1 fraction on tap/drag; null disables seeking.
  final ValueChanged<double>? onSeek;
  final Color? accent;

  const PaperinkVoicePlayback({
    super.key,
    required this.progress,
    required this.isPlaying,
    this.seed = 0,
    this.onSeek,
    this.accent,
  });

  @override
  State<PaperinkVoicePlayback> createState() => _PaperinkVoicePlaybackState();
}

class _PaperinkVoicePlaybackState extends State<PaperinkVoicePlayback>
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
  void didUpdateWidget(covariant PaperinkVoicePlayback old) {
    super.didUpdateWidget(old);
    if (old.isPlaying != widget.isPlaying) _syncTicker();
    if (_ticker == null) _displayed = widget.progress.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  /// Ease the displayed reveal toward the real position (the player's stream
  /// updates in chunks) — this easing IS the roll animation; snap on
  /// seek-sized jumps.
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
    final accent = widget.accent ?? t.action;
    // No wood token; same derivation as the paperink sync visual's board.
    final rod = Color.lerp(t.budgetWilted, t.textPrimary, 0.62)!;

    Widget paint() {
      _step();
      return CustomPaint(
        painter: _ScrollPainter(
          progress: _displayed,
          timeMs: _ticker == null ? -1 : _clock.elapsedMilliseconds,
          seed: widget.seed,
          paper: t.bgRaised,
          paperEdge: t.border,
          sumi: t.textPrimary,
          track: t.textTertiary,
          seal: accent,
          rod: rod,
          rodHi: Color.lerp(rod, t.bgRaised, 0.4)!,
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

class _ScrollPainter extends CustomPainter {
  final double progress;
  final int timeMs; // -1 = static (paused / reduce-motion)
  final int seed;
  final Color paper, paperEdge, sumi, track, seal, rod, rodHi;

  _ScrollPainter({
    required this.progress,
    required this.timeMs,
    required this.seed,
    required this.paper,
    required this.paperEdge,
    required this.sumi,
    required this.track,
    required this.seal,
    required this.rod,
    required this.rodHi,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const rodW = 7.0;
    final paperH = size.height - 8;
    final top = cy - paperH / 2;
    final minX = rodW / 2 + 1;
    final revealX = minX + (size.width - rodW - 2) * progress.clamp(0.0, 1.0);

    // Unrolled-yet paper ahead of the roller: a faint dashed guide line so the
    // whole width still reads as a track.
    final dash = Paint()
      ..color = track.withValues(alpha: 0.45)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (double x = revealX + rodW; x < size.width - 2; x += 7) {
      canvas.drawLine(
        Offset(x, cy),
        Offset(math.min(x + 3.2, size.width - 2), cy),
        dash,
      );
    }

    // Revealed parchment behind the roller.
    final sheet = Rect.fromLTRB(0, top, revealX, top + paperH);
    if (sheet.width > 1) {
      canvas.drawRect(
        sheet.shift(const Offset(0.5, 1.5)),
        Paint()
          ..color = sumi.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
      canvas.drawRect(sheet, Paint()..color = paper);
      canvas.drawRect(
        sheet,
        Paint()
          ..color = paperEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      _paintInkMarks(canvas, sheet, size.width, revealX, paperH, cy);

      // The accent baseline under the played stretch.
      canvas.drawLine(
        Offset(1, top + paperH + 1.5),
        Offset(revealX, top + paperH + 1.5),
        Paint()
          ..color = seal.withValues(alpha: 0.55)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }

    // The rolled scroll at the playhead. Its highlight stripe drifts slightly
    // while playing, hinting at the roller turning.
    final wob = timeMs >= 0 ? math.sin(timeMs / 260.0) * 0.8 : 0.0;
    final rodRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(revealX, cy),
        width: rodW,
        height: paperH + 6,
      ),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(
      rodRect.shift(const Offset(0.5, 1.5)),
      Paint()
        ..color = sumi.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawRRect(rodRect, Paint()..color = rod);
    canvas.drawLine(
      Offset(revealX - 1.2 + wob, cy - paperH / 2 - 1),
      Offset(revealX - 1.2 + wob, cy + paperH / 2 + 1),
      Paint()
        ..color = rodHi.withValues(alpha: 0.8)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Seeded sumi marks brushed along the parchment (mini vertical squiggles
  /// with the occasional horizontal tick, echoing the sync scroll's
  /// calligraphy). The stream is consumed unconditionally per mark so the
  /// geometry doesn't shift as the reveal advances; marks just past the roller
  /// fade in as fresh ink.
  void _paintInkMarks(
    Canvas canvas,
    Rect sheet,
    double fullWidth,
    double revealX,
    double paperH,
    double cy,
  ) {
    canvas.save();
    canvas.clipRect(sheet);
    final rnd = math.Random(seed);
    final markCount = (fullWidth / 12).floor().clamp(2, 80);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;
    for (int i = 0; i < markCount; i++) {
      final xJit = (rnd.nextDouble() - 0.5) * 4;
      final tall = 0.35 + rnd.nextDouble() * 0.4;
      final wig = 0.8 + rnd.nextDouble() * 1.6;
      final ph = rnd.nextDouble() * math.pi * 2;
      final tick = rnd.nextDouble() < 0.45;
      final x = 8.0 + i * 12.0 + xJit;
      final fresh = ((revealX - x) / 14.0).clamp(0.0, 1.0);
      if (fresh <= 0) continue;
      ink.color = sumi.withValues(alpha: 0.78 * fresh);
      final mh = paperH * tall;
      final y0 = cy - mh / 2;
      final path = Path()..moveTo(x, y0);
      for (double yy = 0; yy <= mh; yy += 4) {
        path.lineTo(x + math.sin(yy / mh * math.pi * 1.6 + ph) * wig, y0 + yy);
      }
      canvas.drawPath(path, ink);
      if (tick) {
        final ty = y0 + mh * 0.4;
        canvas.drawLine(Offset(x - 2.5, ty), Offset(x + 3, ty), ink);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScrollPainter old) =>
      old.progress != progress ||
      old.timeMs != timeMs ||
      old.seed != seed ||
      old.paper != paper ||
      old.sumi != sumi ||
      old.seal != seal;
}
