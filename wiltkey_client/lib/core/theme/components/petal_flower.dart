import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Geometry of one petal in the 36×36 concept viewBox.
class _Petal {
  final double cx, cy, rx, ry, rotationDeg;
  const _Petal(this.cx, this.cy, this.rx, this.ry, this.rotationDeg);
}

/// A petal currently detaching (animated by the shared fall controller).
class _Falling {
  final _Petal petal;
  final Color color;
  const _Falling(this.petal, this.color);
}

/// The garden budget glyph: an 8-petal flower whose petals fall off as budget
/// drains. It is a SPLIT flower — the four left petals track *our* budget, the
/// four right petals track the *peer's* budget, each in its own color. Locked /
/// wilted draws a bare dashed center with a few petals on the ground.
///
/// Geometry is lifted directly from `garden-concept.html` (viewBox 36, ellipse
/// petals rx3/ry4.6 at 45° steps, side petals rx4.6/ry3, center circle r4.4).
///
/// Budget granularity is 4 petals per side; exact byte numbers are always shown
/// as adjacent mono text by the caller, so the petals are a glance, not the
/// source of truth.
class PetalFlower extends StatefulWidget {
  final double ourFraction;
  final double theirFraction;
  final bool isWilted;

  /// Rendered edge length in logical pixels (the 36-unit viewBox is scaled to it).
  final double size;

  final Color oursColor;
  final Color peerColor;
  final Color centerFill;
  final Color centerStroke;
  final Color groundColor;
  final Color lockedStroke;

  final Duration fallDuration;
  final bool reduceMotion;
  final String? semanticLabel;

  const PetalFlower({
    super.key,
    required this.ourFraction,
    this.theirFraction = 0,
    required this.isWilted,
    this.size = 36,
    required this.oursColor,
    required this.peerColor,
    required this.centerFill,
    required this.centerStroke,
    required this.groundColor,
    required this.lockedStroke,
    this.fallDuration = const Duration(milliseconds: 900),
    this.reduceMotion = false,
    this.semanticLabel,
  });

  // ---- Petal layout (36-space), ordered clockwise within each side ----
  // The first petal in each list is the last to remain as the side empties.
  static const List<_Petal> _ourPetals = [
    _Petal(7.5, 18, 4.6, 3, 0), // left
    _Petal(10.6, 10.6, 3, 4.6, -45), // top-left
    _Petal(18, 7.5, 3, 4.6, 0), // top
    _Petal(10.6, 25.4, 3, 4.6, 45), // bottom-left
  ];
  static const List<_Petal> _peerPetals = [
    _Petal(28.5, 18, 4.6, 3, 0), // right
    _Petal(25.4, 10.6, 3, 4.6, 45), // top-right
    _Petal(18, 28.5, 3, 4.6, 0), // bottom
    _Petal(25.4, 25.4, 3, 4.6, -45), // bottom-right
  ];

  static int petalsFor(double fraction) =>
      (fraction.clamp(0.0, 1.0) * 4).ceil();

  @override
  State<PetalFlower> createState() => _PetalFlowerState();
}

class _PetalFlowerState extends State<PetalFlower>
    with SingleTickerProviderStateMixin {
  late int _oursShown;
  late int _peerShown;
  late final AnimationController _fall;
  final List<_Falling> _falling = [];

  @override
  void initState() {
    super.initState();
    // Initialize counts WITHOUT triggering a fall on first mount.
    _oursShown = widget.isWilted
        ? 0
        : PetalFlower.petalsFor(widget.ourFraction);
    _peerShown = widget.isWilted
        ? 0
        : PetalFlower.petalsFor(widget.theirFraction);
    _fall = AnimationController(vsync: this, duration: widget.fallDuration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(_falling.clear);
        }
      })
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void didUpdateWidget(PetalFlower old) {
    super.didUpdateWidget(old);
    final newOurs = widget.isWilted
        ? 0
        : PetalFlower.petalsFor(widget.ourFraction);
    final newPeer = widget.isWilted
        ? 0
        : PetalFlower.petalsFor(widget.theirFraction);
    if (newOurs == _oursShown && newPeer == _peerShown) return;

    final dropped = <_Falling>[];
    for (int i = newOurs; i < _oursShown; i++) {
      dropped.add(_Falling(PetalFlower._ourPetals[i], widget.oursColor));
    }
    for (int i = newPeer; i < _peerShown; i++) {
      dropped.add(_Falling(PetalFlower._peerPetals[i], widget.peerColor));
    }

    _oursShown = newOurs;
    _peerShown = newPeer;

    if (dropped.isEmpty || widget.reduceMotion) {
      // Regrowth, or reduce-motion: snap (a quick fade is handled by the
      // surrounding AnimatedTheme/opacity; no per-petal drift).
      setState(() {});
      return;
    }
    setState(() => _falling.addAll(dropped));
    _fall
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _fall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _FlowerPainter(
            oursShown: _oursShown,
            peerShown: _peerShown,
            isWilted: widget.isWilted,
            falling: _falling,
            fallProgress: _fall.value,
            oursColor: widget.oursColor,
            peerColor: widget.peerColor,
            centerFill: widget.centerFill,
            centerStroke: widget.centerStroke,
            groundColor: widget.groundColor,
            lockedStroke: widget.lockedStroke,
          ),
        ),
      ),
    );
  }
}

class _FlowerPainter extends CustomPainter {
  final int oursShown;
  final int peerShown;
  final bool isWilted;
  final List<_Falling> falling;
  final double fallProgress;
  final Color oursColor;
  final Color peerColor;
  final Color centerFill;
  final Color centerStroke;
  final Color groundColor;
  final Color lockedStroke;

  _FlowerPainter({
    required this.oursShown,
    required this.peerShown,
    required this.isWilted,
    required this.falling,
    required this.fallProgress,
    required this.oursColor,
    required this.peerColor,
    required this.centerFill,
    required this.centerStroke,
    required this.groundColor,
    required this.lockedStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 36.0;
    canvas.scale(scale);

    final attachedPetals = oursShown + peerShown;

    // Ground petals: when locked, or when the flower is nearly bare.
    if (isWilted || attachedPetals <= 1) {
      _drawGround(canvas);
    }

    // Attached petals.
    for (int i = 0; i < oursShown; i++) {
      _drawPetal(
        canvas,
        PetalFlower._ourPetals[i],
        oursColor,
        1.0,
        Offset.zero,
        0,
      );
    }
    for (int i = 0; i < peerShown; i++) {
      _drawPetal(
        canvas,
        PetalFlower._peerPetals[i],
        peerColor,
        1.0,
        Offset.zero,
        0,
      );
    }

    // Falling petals (mirrors the concept @keyframes fall).
    if (falling.isNotEmpty) {
      final p = Curves.easeIn.transform(fallProgress);
      final alpha = fallProgress < 0.5 ? 1.0 : 1.0 - (fallProgress - 0.5) / 0.5;
      for (final f in falling) {
        _drawPetal(
          canvas,
          f.petal,
          f.color,
          alpha,
          Offset(7 * p, 26 * p),
          80 * p,
        );
      }
    }

    // Center.
    final centerPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    if (isWilted) {
      strokePaint.color = lockedStroke;
      _drawDashedCircle(canvas, const Offset(18, 18), 4.4, strokePaint);
    } else {
      centerPaint.color = centerFill;
      strokePaint.color = centerStroke;
      canvas.drawCircle(const Offset(18, 18), 4.4, centerPaint);
      canvas.drawCircle(const Offset(18, 18), 4.4, strokePaint);
    }
  }

  void _drawPetal(
    Canvas canvas,
    _Petal petal,
    Color color,
    double alpha,
    Offset drift,
    double extraRotDeg,
  ) {
    canvas.save();
    canvas.translate(petal.cx + drift.dx, petal.cy + drift.dy);
    canvas.rotate((petal.rotationDeg + extraRotDeg) * math.pi / 180);
    final paint = Paint()..color = color.withValues(alpha: alpha);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: petal.rx * 2,
        height: petal.ry * 2,
      ),
      paint,
    );
    canvas.restore();
  }

  void _drawGround(Canvas canvas) {
    final paint = Paint()..color = groundColor;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(11, 30), width: 5.2, height: 2.4),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(20, 32), width: 5.2, height: 2.4),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(27, 30), width: 4.4, height: 2.0),
      paint,
    );
  }

  void _drawDashedCircle(Canvas canvas, Offset c, double r, Paint paint) {
    const int dashes = 10;
    const double gap = 0.45; // fraction of each arc that is empty
    final sweep = (2 * math.pi / dashes) * (1 - gap);
    final rect = Rect.fromCircle(center: c, radius: r);
    for (int i = 0; i < dashes; i++) {
      final start = (2 * math.pi / dashes) * i;
      canvas.drawArc(rect, start, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(_FlowerPainter old) =>
      old.oursShown != oursShown ||
      old.peerShown != peerShown ||
      old.isWilted != isWilted ||
      old.fallProgress != fallProgress ||
      old.falling.length != falling.length;
}
