import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../wiltkey_components.dart';
import '../../wk.dart';

/// Garden proximity scan effect: a dusk meadow. Grass blades sway in the wind
/// and each discovered device sprouts as a flower — near (pairable) Wiltkey
/// peers bloom large in the foreground with a soft pollen halo; far / generic
/// BLE devices are smaller buds toward the horizon. Flowers grow in when found
/// and wilt out when lost (with a short grace period so RSSI flicker doesn't
/// make them pop).
///
/// Owns a single repaint controller; honours reduce-motion (no sway/bob/halo,
/// instant growth). This widget is the `scanning` phase; the connect/transfer/
/// success phases are [GardenVineBloom] below.
class GardenSyncVisual extends StatefulWidget {
  final List<SyncBlip> blips;

  const GardenSyncVisual({super.key, required this.blips});

  @override
  State<GardenSyncVisual> createState() => _GardenSyncVisualState();
}

/// Mutable per-device lifecycle: when it sprouted and (if lost) when it began to
/// wilt out. Keyed by blip id so positions/growth survive frame-to-frame.
class _Flower {
  SyncBlip blip;
  final int spawnMs;
  int? despawnMs;
  _Flower(this.blip, this.spawnMs);
}

class _GardenSyncVisualState extends State<GardenSyncVisual>
    with SingleTickerProviderStateMixin {
  static const int _growMs = 700; // sprout → full bloom
  static const int _fadeMs = 480; // wilt-out
  static const int _graceMs =
      1100; // keep a lost flower this long before wilting

  final Stopwatch _clock = Stopwatch()..start();
  final Map<String, _Flower> _flowers = {};
  AnimationController? _ticker; // repaint pacer only; time comes from _clock

  @override
  void initState() {
    super.initState();
    _sync(widget.blips);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wantMotion = !context.reduceMotion;
    if (wantMotion && _ticker == null) {
      _ticker = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4),
      )..repeat();
    } else if (!wantMotion && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
    }
  }

  @override
  void didUpdateWidget(covariant GardenSyncVisual old) {
    super.didUpdateWidget(old);
    _sync(widget.blips);
  }

  /// Reconcile the incoming blip set against tracked flowers.
  void _sync(List<SyncBlip> blips) {
    final now = _clock.elapsedMilliseconds;
    final seen = <String>{};
    for (final b in blips) {
      seen.add(b.id);
      final existing = _flowers[b.id];
      if (existing == null) {
        _flowers[b.id] = _Flower(b, now);
      } else {
        existing.blip = b;
        existing.despawnMs = null; // revived / still in range
      }
    }
    // Anything no longer present starts (or continues) wilting after the grace
    // period; fully-faded flowers are pruned.
    _flowers.removeWhere((id, f) {
      if (seen.contains(id)) return false;
      f.despawnMs ??= now + _graceMs;
      return now - f.despawnMs! > _fadeMs;
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  static double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();

  static double _easeOutBack(double t) {
    const c = 1.70158;
    final u = t - 1;
    return 1 + (c + 1) * u * u * u + c * u * u;
  }

  /// Resolve the current render state of each flower for this frame.
  List<_FlowerRender> _resolve(bool reduceMotion) {
    final now = _clock.elapsedMilliseconds;
    final out = <_FlowerRender>[];
    for (final f in _flowers.values) {
      final rawGrow = reduceMotion
          ? 1.0
          : ((now - f.spawnMs) / _growMs).clamp(0.0, 1.0);
      double fade = 1.0;
      if (f.despawnMs != null && now >= f.despawnMs!) {
        if (reduceMotion) continue;
        fade = 1.0 - ((now - f.despawnMs!) / _fadeMs).clamp(0.0, 1.0);
        if (fade <= 0) continue;
      }
      out.add(_FlowerRender(blip: f.blip, grow: rawGrow, fade: fade));
    }
    // Paint far/back flowers first so near foreground ones overlap them.
    out.sort((a, b) => a.blip.strength.compareTo(b.blip.strength));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final reduceMotion = context.reduceMotion;

    // Built per-frame so `timeMs` + resolved flowers advance each tick (and on
    // each parent rebuild when motion is reduced and there's no ticker).
    Widget buildField() => CustomPaint(
      painter: _MeadowPainter(
        flowers: _resolve(reduceMotion),
        timeMs: _clock.elapsedMilliseconds,
        reduceMotion: reduceMotion,
        grass: t.positive,
        soil: t.bg,
        peer: t.budgetFill,
        group: t.identity,
        unknown: t.textTertiary,
        center: t.surfacePressed,
        halo: t.action,
        easeGrow: _easeOutCubic,
        easeBloom: _easeOutBack,
      ),
    );

    return Container(
      width: double.infinity,
      height: 200,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.bg, t.bgRaised, t.surface],
          stops: const [0.0, 0.55, 1.0],
        ),
        border: Border.all(color: t.positive.withValues(alpha: 0.22), width: 1),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _ticker == null
                ? buildField()
                : AnimatedBuilder(
                    animation: _ticker!,
                    builder: (_, _) => buildField(),
                  ),
          ),
          Positioned(
            top: 10,
            left: 12,
            child: Row(
              children: [
                Icon(Icons.local_florist_outlined, size: 12, color: t.positive),
                const SizedBox(width: 6),
                Text(
                  widget.blips.isEmpty
                      ? 'Listening for nearby gardens…'
                      : 'Nearby · ${widget.blips.length} found',
                  style: t.bodySecondary.copyWith(
                    fontSize: 11,
                    color: t.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-frame resolved flower (growth 0..1, fade 0..1).
class _FlowerRender {
  final SyncBlip blip;
  final double grow;
  final double fade;
  const _FlowerRender({
    required this.blip,
    required this.grow,
    required this.fade,
  });
}

class _MeadowPainter extends CustomPainter {
  final List<_FlowerRender> flowers;
  final int timeMs;
  final bool reduceMotion;
  final Color grass, soil, peer, group, unknown, center, halo;
  final double Function(double) easeGrow;
  final double Function(double) easeBloom;

  // Deterministic blade field so the meadow is stable across rebuilds.
  static const int _backBlades = 26;
  static const int _frontBlades = 12;
  static final List<_Blade> _back = _genBlades(_backBlades, 0.30, 0.60, 7);
  static final List<_Blade> _front = _genBlades(_frontBlades, 0.46, 0.80, 99);

  _MeadowPainter({
    required this.flowers,
    required this.timeMs,
    required this.reduceMotion,
    required this.grass,
    required this.soil,
    required this.peer,
    required this.group,
    required this.unknown,
    required this.center,
    required this.halo,
    required this.easeGrow,
    required this.easeBloom,
  });

  static List<_Blade> _genBlades(int n, double minH, double maxH, int seed) {
    final r = math.Random(seed);
    return List.generate(n, (i) {
      return _Blade(
        x: r.nextDouble(),
        height: minH + r.nextDouble() * (maxH - minH),
        phase: r.nextDouble() * math.pi * 2,
        width: 3.0 + r.nextDouble() * 3.0,
        shade: r.nextDouble(),
        lean: (r.nextDouble() - 0.5) * 0.5,
      );
    });
  }

  double get _t => timeMs / 1000.0;

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height + 6; // roots just below the frame
    final gust = reduceMotion ? 0.0 : 0.5 + 0.5 * math.sin(_t * 0.6);

    // Back grass (darker, recedes toward the soil).
    for (final b in _back) {
      _drawBlade(
        canvas,
        size,
        b,
        baseY,
        Color.lerp(grass, soil, 0.30 + b.shade * 0.30)!,
        gust,
        0.55,
      );
    }

    // Flowers (sorted far→near by the caller).
    for (final f in flowers) {
      _drawFlower(canvas, size, f, baseY);
    }

    // Front grass (brighter, sunlit) draped over the stems for depth.
    for (final b in _front) {
      _drawBlade(
        canvas,
        size,
        b,
        baseY,
        Color.lerp(grass, halo, 0.12 * b.shade)!,
        gust,
        0.9,
      );
    }

    // Drifting pollen motes.
    if (!reduceMotion) {
      for (int i = 0; i < 5; i++) {
        final seed = (i * 0.61803398875) % 1.0;
        final phase = (_t * 0.06 + seed) % 1.0;
        final x =
            size.width *
            (0.12 +
                0.76 * ((seed * 5) % 1.0) +
                0.03 * math.sin(phase * 2 * math.pi));
        final y = size.height * (0.92 - phase * 0.8);
        final tw = 0.05 + 0.06 * (0.5 + 0.5 * math.sin(phase * 6 * math.pi));
        canvas.drawCircle(
          Offset(x, y),
          1.5,
          Paint()..color = halo.withValues(alpha: tw),
        );
      }
    }
  }

  void _drawBlade(
    Canvas canvas,
    Size size,
    _Blade b,
    double baseY,
    Color color,
    double gust,
    double alpha,
  ) {
    final bx = b.x * size.width;
    final h = b.height * size.height;
    final sway = reduceMotion
        ? b.lean * h * 0.12
        : (b.lean + 0.18 * math.sin(_t * 1.1 + b.phase) * (0.6 + 0.8 * gust)) *
              h *
              0.16;
    final tipX = bx + sway;
    final tipY = baseY - h;
    final midY = baseY - h * 0.5;
    final w = b.width;

    final path = Path()
      ..moveTo(bx - w / 2, baseY)
      ..quadraticBezierTo(bx - w * 0.1 + sway * 0.4, midY, tipX, tipY)
      ..quadraticBezierTo(bx + w * 0.1 + sway * 0.4, midY, bx + w / 2, baseY)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha));
  }

  void _drawFlower(Canvas canvas, Size size, _FlowerRender f, double baseY) {
    final b = f.blip;
    final s = b.strength.clamp(0.0, 1.0);

    // Horizontal: stable from the bearing. Depth from strength.
    final nx = (math.cos(b.angle) * 0.5 + 0.5);
    final x = size.width * (0.12 + 0.76 * nx);
    final groundY =
        baseY - size.height * (0.06 + 0.30 * (1 - s)); // near = lower
    final scale = (0.55 + 0.45 * s);
    final depthAlpha = (b.isWiltkey ? 1.0 : 0.7) * (0.55 + 0.45 * s) * f.fade;

    final grow = easeGrow(f.grow);
    final bloom = easeBloom(f.grow.clamp(0.0, 1.0)).clamp(0.0, 1.2);

    // Gentle bob/sway.
    final bob = reduceMotion
        ? 0.0
        : math.sin(_t * 1.4 + b.angle * 3) * 1.6 * scale;
    final stemSway = reduceMotion
        ? 0.0
        : math.sin(_t * 0.9 + b.angle * 2) * 3.0 * scale;

    final stemLen = 30 * scale * grow;
    final topX = x + stemSway;
    final topY = groundY - stemLen + bob;

    // Stem.
    final stemPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scale
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(
        grass,
        soil,
        0.1,
      )!.withValues(alpha: 0.85 * depthAlpha);
    canvas.drawPath(
      Path()
        ..moveTo(x, groundY)
        ..quadraticBezierTo(
          x + stemSway * 0.5,
          groundY - stemLen * 0.5,
          topX,
          topY,
        ),
      stemPaint,
    );

    if (f.grow < 0.18 && !reduceMotion) return; // still just a sprouting stem

    final petalColor = b.isGroup ? group : (b.isWiltkey ? peer : unknown);

    // Pollen halo for pairable peers.
    if (b.isWiltkey && b.isNear && bloom > 0.5) {
      final pulse = reduceMotion
          ? 0.6
          : 0.5 + 0.5 * math.sin(_t * 2.2 + b.angle);
      final haloR = (9 + 4 * pulse) * scale;
      canvas.drawCircle(
        Offset(topX, topY),
        haloR,
        Paint()
          ..color = halo.withValues(
            alpha: 0.18 * (1 - pulse * 0.5) * depthAlpha,
          )
          ..style = PaintingStyle.fill,
      );
    }

    if (b.isWiltkey || b.isGroup) {
      // Open bloom: 6 petals.
      final petalLen = 6.5 * scale * bloom;
      final petalW = 3.6 * scale * bloom;
      final petalPaint = Paint()
        ..color = petalColor.withValues(alpha: depthAlpha);
      for (int i = 0; i < 6; i++) {
        final a = (i / 6) * math.pi * 2 + b.angle;
        canvas.save();
        canvas.translate(
          topX + math.cos(a) * petalLen * 0.55,
          topY + math.sin(a) * petalLen * 0.55,
        );
        canvas.rotate(a);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: petalLen, height: petalW),
          petalPaint,
        );
        canvas.restore();
      }
      // Center.
      canvas.drawCircle(
        Offset(topX, topY),
        3.0 * scale * bloom.clamp(0.0, 1.0),
        Paint()..color = center.withValues(alpha: depthAlpha),
      );
      canvas.drawCircle(
        Offset(topX, topY),
        3.0 * scale * bloom.clamp(0.0, 1.0),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 * scale
          ..color = Color.lerp(
            petalColor,
            center,
            0.3,
          )!.withValues(alpha: depthAlpha),
      );
    } else {
      // Generic BLE device: a small closed bud (unknown / not a peer).
      final budR = 3.2 * scale * grow;
      canvas.drawCircle(
        Offset(topX, topY),
        budR,
        Paint()..color = unknown.withValues(alpha: depthAlpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MeadowPainter old) =>
      old.timeMs != timeMs || old.flowers != flowers;
}

class _Blade {
  final double x, height, phase, width, shade, lean;
  const _Blade({
    required this.x,
    required this.height,
    required this.phase,
    required this.width,
    required this.shade,
    required this.lean,
  });
}

/// Garden connect → transfer → success visual: a vine grows from each device
/// toward the centre as `progress` climbs; when they meet, a flower blooms and
/// bursts petals outward (the "connection made" moment).
///
/// The real `progress` arrives in jumpy plateaus (10→33→60→90→100); this widget
/// keeps a *displayed* value that eases toward the target every frame, so the
/// vines always creep smoothly. `success` (or progress ≥ 1) triggers the bloom.
///
/// Reduce-motion: no easing/waver, vines drawn at their final length, the bloom
/// cross-fades in with no petal burst.
class GardenVineBloom extends StatefulWidget {
  final SyncVisualState state;
  final double progress;

  /// Optional petal tint for the bloom (e.g. the group `identity` colour). The
  /// vines stay fern; null falls back to the budget marigold.
  final Color? accent;

  const GardenVineBloom({
    super.key,
    required this.state,
    required this.progress,
    this.accent,
  });

  @override
  State<GardenVineBloom> createState() => _GardenVineBloomState();
}

class _GardenVineBloomState extends State<GardenVineBloom>
    with SingleTickerProviderStateMixin {
  static const int _bloomMs = 750;

  final Stopwatch _clock = Stopwatch()..start();
  AnimationController? _ticker;
  double _displayed = 0;
  int _lastMs = 0;
  int? _bloomStartMs;

  double get _target => widget.state == SyncVisualState.success
      ? 1.0
      : widget.progress.clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _displayed = _target;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wantMotion = !context.reduceMotion;
    if (wantMotion && _ticker == null) {
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
  void didUpdateWidget(covariant GardenVineBloom old) {
    super.didUpdateWidget(old);
    // Leaving the success state (e.g. the showcase toggling back) resets the bloom.
    if (widget.state != SyncVisualState.success && _bloomStartMs != null) {
      _bloomStartMs = null;
    }
    if (context.reduceMotion) _displayed = _target;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  static double _easeOutBack(double t) {
    const c = 1.70158;
    final u = t - 1;
    return 1 + (c + 1) * u * u * u + c * u * u;
  }

  /// Advance the eased display value + bloom clock for this frame.
  void _step(bool reduceMotion) {
    final now = _clock.elapsedMilliseconds;
    final dt = ((now - _lastMs).clamp(0, 64)) / 1000.0;
    _lastMs = now;
    if (reduceMotion) {
      _displayed = _target;
    } else {
      // Frame-rate-independent exponential smoothing toward the target.
      _displayed += (_target - _displayed) * (1 - math.exp(-dt * 5.0));
      if ((_target - _displayed).abs() < 0.001) _displayed = _target;
    }
    if (_displayed >= 0.985 && _bloomStartMs == null) _bloomStartMs = now;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final reduceMotion = context.reduceMotion;

    Widget paint() {
      _step(reduceMotion);
      final now = _clock.elapsedMilliseconds;
      double bloomT;
      if (_bloomStartMs == null) {
        bloomT = 0;
      } else if (reduceMotion) {
        bloomT = 1;
      } else {
        bloomT = ((now - _bloomStartMs!) / _bloomMs).clamp(0.0, 1.0);
      }
      return CustomPaint(
        painter: _VineBloomPainter(
          vine: _displayed,
          bloomT: bloomT,
          bloomEased: _easeOutBack(bloomT),
          timeMs: now,
          reduceMotion: reduceMotion,
          vineColor: t.positive,
          petalColor: widget.accent ?? t.budgetFill,
          center: t.surfacePressed,
          node: t.surface,
          nodeStroke: t.positive,
          halo: t.action,
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 170,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.bg, t.bgRaised],
        ),
        border: Border.all(color: t.positive.withValues(alpha: 0.22), width: 1),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: _ticker == null
          ? paint()
          : AnimatedBuilder(animation: _ticker!, builder: (_, _) => paint()),
    );
  }
}

class _VineBloomPainter extends CustomPainter {
  final double vine; // 0..1 displayed growth toward centre
  final double bloomT; // 0..1 linear bloom
  final double bloomEased; // eased bloom (overshoot)
  final int timeMs;
  final bool reduceMotion;
  final Color vineColor, petalColor, center, node, nodeStroke, halo;

  // Stable petal-burst directions/speeds.
  static const int _burst = 11;
  static final List<double> _burstAng = List.generate(
    _burst,
    (i) => i * (2 * math.pi / _burst) + (i.isEven ? 0.21 : -0.13),
  );
  static final List<double> _burstSpd = List.generate(
    _burst,
    (i) => 0.75 + ((i * 0.37) % 1.0) * 0.5,
  );

  _VineBloomPainter({
    required this.vine,
    required this.bloomT,
    required this.bloomEased,
    required this.timeMs,
    required this.reduceMotion,
    required this.vineColor,
    required this.petalColor,
    required this.center,
    required this.node,
    required this.nodeStroke,
    required this.halo,
  });

  double get _t => timeMs / 1000.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height * 0.5;
    final cx = size.width * 0.5;
    const pad = 22.0;
    const gap = 12.0; // how close the tips get before the bloom bridges them
    final reach = (cx - gap) - pad; // full horizontal run of each vine

    _drawVine(canvas, anchorX: pad, cy: cy, reach: reach, dir: 1.0, seed: 1207);
    _drawVine(
      canvas,
      anchorX: size.width - pad,
      cy: cy,
      reach: reach,
      dir: -1.0,
      seed: 5519,
    );

    // Device nodes at each end.
    for (final ax in [pad, size.width - pad]) {
      canvas.drawCircle(Offset(ax, cy), 7, Paint()..color = node);
      canvas.drawCircle(
        Offset(ax, cy),
        7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = nodeStroke.withValues(alpha: 0.7),
      );
    }

    if (bloomT > 0) _drawBloom(canvas, Offset(cx, cy));
  }

  /// Builds the full, deterministic meandering vine for one side: a fixed seeded
  /// shape (anchor → near-centre) with gentle sway layered on (pinned at the
  /// root, growing toward the tip). The same seed yields the same base shape
  /// every frame, so only the sway and the revealed length change.
  Path _vinePath(
    double anchorX,
    double cy,
    double dir,
    double reach,
    int seed,
  ) {
    final rnd = math.Random(seed);
    const segs = 7;
    final pts = <Offset>[];
    for (int i = 0; i <= segs; i++) {
      final f = i / segs;
      final x = anchorX + dir * reach * f;
      // Irregular meander, pinned to ~0 at both ends so root and tip sit on line.
      final amp = (i == 0 || i == segs) ? 0.0 : (rnd.nextDouble() * 2 - 1) * 17;
      final sway = reduceMotion ? 0.0 : math.sin(_t * 1.3 + i * 0.9) * 7.0 * f;
      pts.add(Offset(x, cy - 4 + amp + sway));
    }
    // Smooth curve through the points (quadratics via midpoints).
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

  void _drawVine(
    Canvas canvas, {
    required double anchorX,
    required double cy,
    required double reach,
    required double dir,
    required int seed,
  }) {
    final full = _vinePath(anchorX, cy, dir, reach, seed);
    final metrics = full.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final shownLen = metric.length * vine;

    // Reveal only the grown section of the premade vine.
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = vineColor.withValues(alpha: 0.9);
    canvas.drawPath(metric.extractPath(0, shownLen), paint);

    // Leaves sprout along the curve, oriented to its tangent, as the tip passes.
    const leafFracs = [0.26, 0.46, 0.66, 0.84];
    for (int i = 0; i < leafFracs.length; i++) {
      final lf = leafFracs[i];
      if (vine <= lf) continue;
      final grow = ((vine - lf) / 0.10).clamp(0.0, 1.0);
      final tan = metric.getTangentForOffset(metric.length * lf);
      if (tan == null) continue;
      final side = i.isEven ? -1.0 : 1.0;
      canvas.save();
      canvas.translate(tan.position.dx, tan.position.dy);
      canvas.rotate(tan.angle + side * 0.7); // splay outward from the stem
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -6.5 * grow),
          width: 5.5 * grow,
          height: 12 * grow,
        ),
        Paint()..color = vineColor.withValues(alpha: 0.85),
      );
      canvas.restore();
    }
  }

  void _drawBloom(Canvas canvas, Offset c) {
    // Brief pollen halo behind the flower.
    if (bloomT < 1 && !reduceMotion) {
      final r = 22 + 40 * bloomT;
      canvas.drawCircle(
        c,
        r,
        Paint()..color = halo.withValues(alpha: 0.22 * (1 - bloomT)),
      );
    }

    // Exploding petals.
    if (!reduceMotion && bloomT > 0) {
      final dist = 14 + 52 * Curves.easeOut.transform(bloomT);
      final a = (1 - bloomT);
      for (int i = 0; i < _burst; i++) {
        final ang = _burstAng[i];
        final p =
            c + Offset(math.cos(ang), math.sin(ang)) * dist * _burstSpd[i];
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(ang);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: 10 * a + 3,
            height: 4.5 * a + 1.5,
          ),
          Paint()..color = petalColor.withValues(alpha: 0.85 * a),
        );
        canvas.restore();
      }
    }

    // The central flower opening — two offset petal rings for a fuller bloom.
    final s = bloomEased.clamp(0.0, 1.2);
    final petalPaint = Paint()..color = petalColor;
    final backPaint = Paint()..color = Color.lerp(petalColor, center, 0.18)!;
    for (final ring in [
      (count: 8, len: 35.0, w: 15.5, off: 0.0, back: true),
      (count: 8, len: 25.0, w: 10.0, off: math.pi / 8, back: false),
    ]) {
      final petalLen = ring.len * s;
      final petalW = ring.w * s;
      for (int i = 0; i < ring.count; i++) {
        final ang = (i / ring.count) * 2 * math.pi + ring.off;
        canvas.save();
        canvas.translate(
          c.dx + math.cos(ang) * petalLen * 0.52,
          c.dy + math.sin(ang) * petalLen * 0.52,
        );
        canvas.rotate(ang);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: petalLen, height: petalW),
          ring.back ? backPaint : petalPaint,
        );
        canvas.restore();
      }
    }
    final cr = 7.0 * bloomT.clamp(0.0, 1.0);
    canvas.drawCircle(c, cr, Paint()..color = center);
    canvas.drawCircle(
      c,
      cr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = Color.lerp(petalColor, center, 0.3)!,
    );
  }

  @override
  bool shouldRepaint(covariant _VineBloomPainter old) =>
      old.timeMs != timeMs || old.vine != vine || old.bloomT != bloomT;
}
