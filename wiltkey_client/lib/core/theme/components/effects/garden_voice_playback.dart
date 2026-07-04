import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../wk.dart';

/// Garden voice-note scrubber: a fixed wavy vine spanning the bubble. The
/// stretch behind the playhead comes alive in lively green while the rest
/// stays a dry brown (derived — there's no brown token, same trick as the
/// nuke), and leaves are revealed along the vine as playback reaches them.
/// While playing the revealed leaves sway gently and a bud pulses at the
/// playhead; under reduce-motion everything is static but the played/unplayed
/// split still reads as a progress bar. Tap/drag anywhere seeks.
class GardenVoicePlayback extends StatefulWidget {
  /// Playhead position, 0..1.
  final double progress;
  final bool isPlaying;

  /// Stable per-message seed (the bubble passes the message id's hash).
  final int seed;

  /// Called with a 0..1 fraction on tap/drag; null disables seeking.
  final ValueChanged<double>? onSeek;
  final Color? accent;

  const GardenVoicePlayback({
    super.key,
    required this.progress,
    required this.isPlaying,
    this.seed = 0,
    this.onSeek,
    this.accent,
  });

  @override
  State<GardenVoicePlayback> createState() => _GardenVoicePlaybackState();
}

class _GardenVoicePlaybackState extends State<GardenVoicePlayback>
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
  void didUpdateWidget(covariant GardenVoicePlayback old) {
    super.didUpdateWidget(old);
    if (old.isPlaying != widget.isPlaying) _syncTicker();
    if (_ticker == null) _displayed = widget.progress.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  /// Ease the displayed playhead toward the real position (the player's
  /// stream updates in chunks); snap on seek-sized jumps.
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

    Widget paint() {
      _step();
      return CustomPaint(
        painter: _VinePainter(
          progress: _displayed,
          timeMs: _ticker == null ? -1 : _clock.elapsedMilliseconds,
          seed: widget.seed,
          // No brown token; derive the dry vine like the nuke does.
          brown: Color.lerp(t.warning, t.budgetWilted, 0.6)!,
          green: t.positive,
          // Tint the leaves slightly toward the accent so a group sender's
          // identity colour reads on their messages.
          leaf: Color.lerp(t.positive, accent, 0.25)!,
          bud: accent,
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

class _VinePainter extends CustomPainter {
  final double progress;
  final int timeMs; // -1 = static (paused / reduce-motion)
  final int seed;
  final Color brown; // dry, unplayed vine
  final Color green; // lively, played vine
  final Color leaf;
  final Color bud;

  _VinePainter({
    required this.progress,
    required this.timeMs,
    required this.seed,
    required this.brown,
    required this.green,
    required this.leaf,
    required this.bud,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // One seeded stream, consumed in a fixed order (vine, then leaves), so the
    // geometry is stable per message and identical on both peers.
    final rnd = math.Random(seed);
    final path = _vine(size, rnd);
    final metric = path.computeMetrics().first;
    final total = metric.length;
    final playedLen = total * progress.clamp(0.0, 1.0);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.0
        ..color = brown,
    );

    if (playedLen > 0) {
      canvas.drawPath(
        metric.extractPath(0, playedLen),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.4
          ..color = green,
      );
    }

    // Leaves along the vine, revealed up to the playhead. Their side/size/
    // sway phase come from the seeded stream (consumed unconditionally so the
    // sequence doesn't shift with progress).
    final leafCount = (size.width / 26).floor().clamp(2, 24);
    for (int k = 0; k < leafCount; k++) {
      final side = rnd.nextBool() ? 1.0 : -1.0;
      final sizeJit = 0.85 + rnd.nextDouble() * 0.4;
      final phase = rnd.nextDouble() * math.pi * 2;
      final d = total * (k + 0.7) / (leafCount + 1);
      if (d > playedLen) continue; // playback hasn't reached this leaf yet
      final tan = metric.getTangentForOffset(d);
      if (tan == null) continue;
      final sway = timeMs >= 0 ? math.sin(timeMs / 450.0 + phase) * 0.16 : 0.0;
      canvas.save();
      canvas.translate(tan.position.dx, tan.position.dy);
      canvas.rotate(tan.angle + side * 0.85 + sway);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(4.5 * sizeJit, 0),
          width: 8.0 * sizeJit,
          height: 4.2 * sizeJit,
        ),
        Paint()..color = leaf,
      );
      canvas.restore();
    }

    // The playhead bud, pulsing softly while playing.
    final head = metric.getTangentForOffset(playedLen.clamp(0.0, total));
    if (head != null) {
      if (timeMs >= 0) {
        final pulse = 0.5 + 0.5 * math.sin(timeMs / 300.0);
        canvas.drawCircle(
          head.position,
          5.5,
          Paint()..color = bud.withValues(alpha: 0.10 + 0.16 * pulse),
        );
      }
      canvas.drawCircle(head.position, 3.0, Paint()..color = bud);
    }
  }

  /// The seeded meander: a fixed wavy path spanning the width, anchored to the
  /// vertical centre at both ends.
  Path _vine(Size size, math.Random rnd) {
    final cy = size.height / 2;
    final amp = size.height * 0.26;
    const n = 8;
    final pts = <Offset>[];
    for (int i = 0; i <= n; i++) {
      final x = size.width * i / n;
      final y = (i == 0 || i == n) ? cy : cy + (rnd.nextDouble() * 2 - 1) * amp;
      pts.add(Offset(x, y));
    }
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length - 1; i++) {
      final mid = Offset(
        (pts[i].dx + pts[i + 1].dx) / 2,
        (pts[i].dy + pts[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  @override
  bool shouldRepaint(covariant _VinePainter old) =>
      old.progress != progress ||
      old.timeMs != timeMs ||
      old.seed != seed ||
      old.brown != brown ||
      old.green != green ||
      old.leaf != leaf ||
      old.bud != bud;
}
