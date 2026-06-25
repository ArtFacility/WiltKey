import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../wiltkey_components.dart';
import '../../wk.dart';

/// Paper & Ink BLE scan visual: pinned paper talismans (ofuda).
///
/// Its own visual language — not a radar, and not the garden meadow either.
/// Each discovered device is a slip of washi paper bearing a brushed kanji that
/// **falls** gently into the panel, fluttering and swaying like real paper. When
/// it reaches its rest height it is **pinned** — a needle drives in from the
/// direction the signal came from, the slip's drift stops dead, its body goes
/// stiff, and from then on only its free bottom corners stir in the draught.
///
/// * **Proximity is depth.** A near/strong peer falls lower (foreground), bigger
///   and crisper; a far/weak device hangs higher up, smaller and paler. Once
///   pinned it never moves again, so RSSI flicker can't make slips jitter.
/// * **Peers are sealed in red.** A Wiltkey peer's kanji is the key character 鍵,
///   stamped in vermilion — the theme's one color, used as a seal. Generic BLE
///   devices carry a neutral character (音/影/遠/客) brushed in plain sumi ink.
/// * **Lost devices come unpinned** and flutter away downward as they fade.
///
/// Owns a single repaint pacer; honours reduce-motion (slips appear already
/// pinned and still). No terminal text.
class PaperinkSyncVisual extends StatefulWidget {
  final List<SyncBlip> blips;
  final List<String> log; // accepted for API parity; intentionally unused

  const PaperinkSyncVisual({super.key, required this.blips, required this.log});

  @override
  State<PaperinkSyncVisual> createState() => _PaperinkSyncVisualState();
}

// Neutral, benign characters for generic (non-Wiltkey) devices. The Wiltkey
// "key" character 鍵 is handled separately (it gets the vermilion seal).
const List<String> _genericKanji = [
  '音',
  '影',
  '遠',
  '客',
]; // sound, shadow, far, guest
const String _keyKanji = '鍵'; // key

/// Mutable per-device lifecycle. Geometry/character are fixed at spawn (from the
/// id hash + the strength at the moment it was found) so a pinned slip stays put
/// even as live RSSI wobbles. Keyed by blip id.
class _Slip {
  SyncBlip blip;
  final int spawnMs;
  int? despawnMs;

  final double strength; // captured at spawn → drives depth/size
  final double rx; // 0..1 horizontal rest position
  final double yJitter; // -1..1 within the depth band
  final double swayPhase;
  final double rotPhase;
  final double flutterPhase;
  final double w;
  final double h;
  final bool peer;
  final TextPainter glyph; // laid out once

  _Slip(
    this.blip,
    this.spawnMs, {
    required this.strength,
    required this.rx,
    required this.yJitter,
    required this.swayPhase,
    required this.rotPhase,
    required this.flutterPhase,
    required this.w,
    required this.h,
    required this.peer,
    required this.glyph,
  });
}

class _SlipRender {
  final _Slip slip;
  final double fallPhase; // 0→1 falling → reaches pin
  final double stiffen; // 0→1 after pinning (body locks, sway/flutter damp)
  final double pinGrow; // 0→1 needle drives in
  final double recoil; // signed, decaying kick along the arrow's travel
  final double fade; // 1→0 unpinned drift-away
  const _SlipRender({
    required this.slip,
    required this.fallPhase,
    required this.stiffen,
    required this.pinGrow,
    required this.recoil,
    required this.fade,
  });
}

class _PaperinkSyncVisualState extends State<PaperinkSyncVisual>
    with SingleTickerProviderStateMixin {
  static const int _fallMs = 1500; // drift down → pinned
  static const int _stiffenMs = 90; // body snaps rigid almost at once
  static const int _pinMs = 70; // needle drives in fast
  static const int _recoilMs = 150; // sharp directional kick on impact
  static const int _fadeMs = 700; // unpinned drift-away
  static const int _graceMs = 1200; // hold a lost slip before it lets go

  final Stopwatch _clock = Stopwatch()..start();
  final Map<String, _Slip> _slips = {};
  AnimationController? _ticker;

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
        duration: const Duration(seconds: 6),
      )..repeat();
    } else if (!wantMotion && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
    }
  }

  @override
  void didUpdateWidget(covariant PaperinkSyncVisual old) {
    super.didUpdateWidget(old);
    _sync(widget.blips);
  }

  int _hash(String s) {
    var h = 0;
    for (var i = 0; i < s.length; i++) {
      h = 31 * h + s.codeUnitAt(i);
    }
    return h & 0x7fffffff;
  }

  void _sync(List<SyncBlip> blips) {
    final now = _clock.elapsedMilliseconds;
    final seen = <String>{};
    for (final b in blips) {
      seen.add(b.id);
      final existing = _slips[b.id];
      if (existing == null) {
        _slips[b.id] = _make(b, now);
      } else {
        existing.blip = b;
        existing.despawnMs = null; // revived / still in range
      }
    }
    _slips.removeWhere((id, s) {
      if (seen.contains(id)) return false;
      s.despawnMs ??= now + _graceMs;
      final gone = now - s.despawnMs! > _fadeMs;
      if (gone) s.glyph.dispose();
      return gone;
    });
  }

  _Slip _make(SyncBlip b, int now) {
    final rand = math.Random(_hash(b.id));
    final s = b.strength.clamp(0.0, 1.0);
    final peer = b.isWiltkey;
    // Near = bigger; far = smaller (a tall ofuda slip).
    final h = 38.0 + 18.0 * s;
    final w = h * 0.62;
    final kanji = peer
        ? _keyKanji
        : _genericKanji[_hash(b.id) % _genericKanji.length];
    final glyph = TextPainter(
      text: TextSpan(
        text: kanji,
        style: TextStyle(
          fontFamily: 'ShipporiMincho',
          fontWeight: FontWeight.w700,
          fontSize: h * 0.5,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return _Slip(
      b,
      now,
      strength: s,
      rx: rand.nextDouble(),
      yJitter: rand.nextDouble() * 2 - 1,
      swayPhase: rand.nextDouble() * math.pi * 2,
      rotPhase: rand.nextDouble() * math.pi * 2,
      flutterPhase: rand.nextDouble() * math.pi * 2,
      w: w,
      h: h,
      peer: peer,
      glyph: glyph,
    );
  }

  @override
  void dispose() {
    for (final s in _slips.values) {
      s.glyph.dispose();
    }
    _ticker?.dispose();
    super.dispose();
  }

  List<_SlipRender> _resolve(bool reduceMotion) {
    final now = _clock.elapsedMilliseconds;
    final out = <_SlipRender>[];
    for (final s in _slips.values) {
      final fallPhase = reduceMotion
          ? 1.0
          : ((now - s.spawnMs) / _fallMs).clamp(0.0, 1.0);
      final pinned = fallPhase >= 1.0;
      final pinElapsed = now - (s.spawnMs + _fallMs);
      final stiffen = reduceMotion
          ? 1.0
          : (pinned ? (pinElapsed / _stiffenMs).clamp(0.0, 1.0) : 0.0);
      final pinGrow = reduceMotion
          ? 1.0
          : (pinned ? (pinElapsed / _pinMs).clamp(0.0, 1.0) : 0.0);
      // A sharp, fast-decaying kick when the arrow bites — a couple of
      // oscillations that die out within _recoilMs (no soft sine hump).
      double recoil = 0.0;
      if (!reduceMotion && pinned && pinElapsed < _recoilMs) {
        final t01 = pinElapsed / _recoilMs;
        recoil = (1 - t01) * (1 - t01) * math.sin(t01 * math.pi * 3.2);
      }

      double fade = 1.0;
      if (s.despawnMs != null && now >= s.despawnMs!) {
        if (reduceMotion) continue;
        fade = 1.0 - ((now - s.despawnMs!) / _fadeMs).clamp(0.0, 1.0);
        if (fade <= 0) continue;
      }
      out.add(
        _SlipRender(
          slip: s,
          fallPhase: fallPhase,
          stiffen: stiffen,
          pinGrow: pinGrow,
          recoil: recoil,
          fade: fade,
        ),
      );
    }
    // Far/back slips first so near foreground ones overlap them.
    out.sort((a, b) => a.slip.strength.compareTo(b.slip.strength));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final reduceMotion = context.reduceMotion;

    // No "wood" token exists, so derive a warm board from the warmest tokens:
    // the wilted tan tinted toward sumi (base + a darker grain).
    final boardBase = Color.lerp(t.budgetWilted, t.textPrimary, 0.42)!;
    final boardGrain = Color.lerp(t.budgetWilted, t.textPrimary, 0.62)!;

    Widget buildSheet() => CustomPaint(
      painter: _OfudaPainter(
        slips: _resolve(reduceMotion),
        timeMs: _clock.elapsedMilliseconds,
        reduceMotion: reduceMotion,
        paper: t.bgRaised,
        paperEdge: t.border,
        sumi: t.textPrimary,
        wash: t.textSecondary,
        dust: t.textTertiary,
        seal: t.action,
        boardBase: boardBase,
        boardGrain: boardGrain,
      ),
    );

    return Container(
      width: double.infinity,
      height: 200,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: boardBase,
        border: Border.all(color: boardGrain, width: t.borderWidth),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _ticker == null
                ? buildSheet()
                : AnimatedBuilder(
                    animation: _ticker!,
                    builder: (context, _) => buildSheet(),
                  ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Text(
              t.uppercaseLabels
                  ? 'LISTENING FOR NEARBY KEYS · ${widget.blips.length} FOUND'
                  : 'Listening for nearby keys · ${widget.blips.length} found',
              style: t.dataMono.copyWith(
                color: t.bgRaised.withValues(alpha: 0.85),
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Painter — falling, pinned ofuda
// =============================================================================

class _OfudaPainter extends CustomPainter {
  final List<_SlipRender> slips;
  final int timeMs;
  final bool reduceMotion;
  final Color paper;
  final Color paperEdge;
  final Color sumi;
  final Color wash;
  final Color dust;
  final Color seal;
  final Color boardBase;
  final Color boardGrain;

  _OfudaPainter({
    required this.slips,
    required this.timeMs,
    required this.reduceMotion,
    required this.paper,
    required this.paperEdge,
    required this.sumi,
    required this.wash,
    required this.dust,
    required this.seal,
    required this.boardBase,
    required this.boardGrain,
  });

  double get _t => timeMs / 1000.0;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBoard(canvas, size);

    // Faint paper dust drifting up in the light — quiet ambient life.
    if (!reduceMotion) {
      for (int i = 0; i < 4; i++) {
        final seed = (i * 0.61803398875) % 1.0;
        final ph = (_t * 0.05 + seed) % 1.0;
        final x =
            size.width *
            (0.1 +
                0.8 * ((seed * 7) % 1.0) +
                0.02 * math.sin(ph * 2 * math.pi));
        final y = size.height * (0.95 - ph * 0.85);
        final tw = 0.04 + 0.05 * (0.5 + 0.5 * math.sin(ph * 6 * math.pi));
        canvas.drawCircle(
          Offset(x, y),
          1.2,
          Paint()..color = dust.withValues(alpha: tw),
        );
      }
    }

    for (final r in slips) {
      _paintSlip(canvas, size, r);
    }
  }

  /// A weathered wood board the slips get pinned into — derived warm taupe with
  /// a few horizontal plank seams and wavy grain. Static; drawn behind the dust.
  void _paintBoard(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = boardBase);

    // Vertical shade — a touch darker toward the bottom for depth.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            boardGrain.withValues(alpha: 0.0),
            boardGrain.withValues(alpha: 0.18),
          ],
        ).createShader(Offset.zero & size),
    );

    // Horizontal plank seams.
    const planks = 3;
    final seam = Paint()
      ..color = boardGrain.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (int i = 1; i < planks; i++) {
      final y = size.height * i / planks;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), seam);
    }

    // Wavy grain streaks (deterministic; static board).
    final grain = Paint()
      ..color = boardGrain.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final rand = math.Random(11);
    for (int i = 0; i < 7; i++) {
      final y0 = size.height * (i + 0.5) / 7;
      final amp = 2.0 + rand.nextDouble() * 4.0;
      final freq = 1.5 + rand.nextDouble() * 2.0;
      final phase = rand.nextDouble() * math.pi * 2;
      final path = Path()..moveTo(0, y0);
      for (double x = 0; x <= size.width; x += 8) {
        path.lineTo(
          x,
          y0 + math.sin(x / size.width * freq * math.pi * 2 + phase) * amp,
        );
      }
      canvas.drawPath(path, grain);
    }
  }

  void _paintSlip(Canvas canvas, Size size, _SlipRender r) {
    final s = r.slip;
    final opacity = r.fade * _lerp(0.6, 1.0, s.strength);
    if (opacity <= 0.01) return;

    final w = s.w;
    final h = s.h;

    // Rest position. Near (strong) rests low/foreground; far rests high.
    final restX = size.width * (0.14 + s.rx * 0.72);
    final bandTop = 46.0;
    final bandBot = size.height - h * 0.5 - 10;
    final restY = _lerp(bandTop, bandBot, s.strength) + s.yJitter * 7.0;
    final startY = -h;

    // Vertical travel: keep momentum into the pin (mild ease-in) so the stop
    // reads as an abrupt snap, not a glide to rest.
    final fall =
        r.fallPhase * r.fallPhase * (2 - r.fallPhase); // ~linear, slight bite
    double cy = _lerp(startY, restY, fall);
    // Sway + body rotation while falling; both damp to a small settled tilt
    // once pinned (only the corners keep moving after that).
    final live = (1 - r.stiffen);
    final settledTilt = math.sin(s.blip.angle) * 0.10;
    final osc = math.sin(_t * 1.5 + s.rotPhase) * 0.22;
    double rot = reduceMotion
        ? settledTilt
        : osc * live + settledTilt * r.stiffen;
    final swayX = reduceMotion
        ? 0.0
        : math.sin(_t * 1.25 + s.swayPhase) * 11.0 * live;
    // Sharp impact kick along the arrow's travel (it flies in from blip.angle,
    // so it shoves the slip toward the opposite side) plus a quick rotation jerk.
    final dir = Offset(math.cos(s.blip.angle), math.sin(s.blip.angle));
    final kick = -dir * (9.0 * r.recoil);
    rot += r.recoil * 0.22;
    // While unpinned-and-fading, let it slide away downward.
    final drift = (1 - r.fade) * 26.0;
    final cx = restX + swayX + kick.dx;
    cy += drift + kick.dy;

    final needGroup = opacity < 0.998;
    if (needGroup) {
      canvas.saveLayer(
        Rect.fromCenter(center: Offset(cx, cy), width: w * 3, height: h * 3),
        // RGB ignored; only alpha is used as the group's opacity.
        Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
      );
    }

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rot);

    // --- paper body (bottom corners flutter; top is held by the pin) ---
    final hw = w / 2;
    final hh = h / 2;
    final flutterAmp = reduceMotion ? 0.0 : _lerp(4.5, 1.4, r.stiffen);
    final blx = math.sin(_t * 3.1 + s.flutterPhase) * flutterAmp;
    final bly = math.cos(_t * 2.7 + s.flutterPhase) * flutterAmp * 0.5;
    final brx = math.sin(_t * 3.1 + s.flutterPhase + 1.7) * flutterAmp;
    final bry = math.cos(_t * 2.7 + s.flutterPhase + 1.7) * flutterAmp * 0.5;

    final body = Path()
      ..moveTo(-hw, -hh)
      ..lineTo(hw, -hh)
      ..lineTo(hw + brx, hh + bry)
      ..quadraticBezierTo(
        (brx - blx) * 0.5,
        hh + (bly + bry) * 0.5 + flutterAmp * 0.6,
        -hw + blx,
        hh + bly,
      )
      ..close();

    // soft paper shadow (offset, no glow)
    canvas.drawPath(
      body.shift(const Offset(1.5, 2.5)),
      Paint()
        ..color = sumi.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
    canvas.drawPath(body, Paint()..color = paper);
    canvas.drawPath(
      body,
      Paint()
        ..color = paperEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // --- the kanji, brushed/stamped on ---
    final glyphColor = s.peer ? seal : sumi;
    final tp = s.glyph;
    // Fade the ink in over the first part of the fall so it reads as settling.
    final inkIn = reduceMotion ? 1.0 : (r.fallPhase * 1.4).clamp(0.0, 1.0);
    _paintGlyph(
      canvas,
      tp,
      Offset(-tp.width / 2, -tp.height / 2),
      glyphColor.withValues(alpha: inkIn),
    );

    // --- the pin ---
    if (r.pinGrow > 0 && r.fade > 0.4) {
      _paintPin(canvas, s, hw, hh, r.pinGrow);
    }

    canvas.restore();
    if (needGroup) canvas.restore();
  }

  void _paintGlyph(Canvas canvas, TextPainter tp, Offset at, Color color) {
    // The glyph is laid out without a baked color, so tint (and apply its alpha)
    // through a srcIn layer — lets one cached TextPainter render in seal or sumi.
    canvas.saveLayer(
      Rect.fromLTWH(at.dx - 1, at.dy - 1, tp.width + 2, tp.height + 2),
      Paint(),
    );
    tp.paint(canvas, at);
    canvas.drawRect(
      Rect.fromLTWH(at.dx - 1, at.dy - 1, tp.width + 2, tp.height + 2),
      Paint()
        ..color = color
        ..blendMode = BlendMode.srcIn,
    );
    canvas.restore();
  }

  void _paintPin(Canvas canvas, _Slip s, double hw, double hh, double grow) {
    // Pin point near the top of the slip; the needle trails back toward the
    // direction the signal arrived from.
    final point = Offset(0, -hh * 0.62);
    final dir = Offset(math.cos(s.blip.angle), math.sin(s.blip.angle));
    final shaftLen = 13.0 * grow;
    final tail = point + dir * shaftLen;

    canvas.drawLine(
      point,
      tail,
      Paint()
        ..color = wash
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );
    // pin head
    canvas.drawCircle(point, 2.6 * grow, Paint()..color = sumi);
    canvas.drawCircle(
      point - dir * 0.6,
      1.0 * grow,
      Paint()..color = paper.withValues(alpha: 0.7),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _OfudaPainter old) =>
      old.timeMs != timeMs ||
      old.slips != slips ||
      old.sumi != sumi ||
      old.seal != seal;
}

// =============================================================================
// Pairing sync: an emakimono handscroll unrolls, calligraphy is brushed on as
// it opens, and on success a vermilion hanko is stamped in the centre.
// =============================================================================

const String _sealKanji = '結'; // musubi — "bond / tie" (a connection formed)

/// The connect → transfer → success phases of pairing for Paper & Ink.
///
/// A handscroll unrolls from the centre outward (two wooden rollers parting, one
/// per device) as `progress` climbs; ink columns are brushed on column-by-column
/// as fresh paper is revealed. On success the scroll is full and a hanko stamp
/// drops, bites, and lifts — leaving a vermilion 結 seal in the middle.
///
/// `accent` is accepted for API parity but ignored: the seal stays vermilion
/// (`t.action`) to keep the theme's "red = seal only" discipline. Honours
/// reduce-motion (opens to target instantly; success shows a static seal).
class PaperinkSyncScroll extends StatefulWidget {
  final SyncVisualState state;
  final double progress;
  final Color? accent;

  const PaperinkSyncScroll({
    super.key,
    required this.state,
    required this.progress,
    this.accent,
  });

  @override
  State<PaperinkSyncScroll> createState() => _PaperinkSyncScrollState();
}

class _PaperinkSyncScrollState extends State<PaperinkSyncScroll>
    with SingleTickerProviderStateMixin {
  static const int _stampMs = 720; // drop → bite → lift → settled seal

  final Stopwatch _clock = Stopwatch()..start();
  AnimationController? _ticker;
  double _displayed = 0;
  int _lastMs = 0;
  int? _stampStartMs;

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
  void didUpdateWidget(covariant PaperinkSyncScroll old) {
    super.didUpdateWidget(old);
    // Leaving success (e.g. the showcase toggling back) resets the stamp.
    if (widget.state != SyncVisualState.success && _stampStartMs != null) {
      _stampStartMs = null;
    }
    if (context.reduceMotion) _displayed = _target;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _step(bool reduceMotion) {
    final now = _clock.elapsedMilliseconds;
    final dt = ((now - _lastMs).clamp(0, 64)) / 1000.0;
    _lastMs = now;
    if (reduceMotion) {
      _displayed = _target;
    } else {
      _displayed += (_target - _displayed) * (1 - math.exp(-dt * 5.0));
      if ((_target - _displayed).abs() < 0.001) _displayed = _target;
    }
    final atSuccess = widget.state == SyncVisualState.success;
    if (atSuccess && _displayed >= 0.985 && _stampStartMs == null) {
      _stampStartMs = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final reduceMotion = context.reduceMotion;

    final boardBase = Color.lerp(t.budgetWilted, t.textPrimary, 0.42)!;
    final boardGrain = Color.lerp(t.budgetWilted, t.textPrimary, 0.62)!;

    Widget paint() {
      _step(reduceMotion);
      final now = _clock.elapsedMilliseconds;
      double stampT;
      if (_stampStartMs == null) {
        stampT = 0;
      } else if (reduceMotion) {
        stampT = 1;
      } else {
        stampT = ((now - _stampStartMs!) / _stampMs).clamp(0.0, 1.0);
      }
      return CustomPaint(
        painter: _ScrollSealPainter(
          open: _displayed,
          stampT: stampT,
          timeMs: now,
          reduceMotion: reduceMotion,
          paper: t.bgRaised,
          paperEdge: t.border,
          sumi: t.textPrimary,
          wash: t.textSecondary,
          seal: t.action,
          rod: boardGrain,
          rodHi: Color.lerp(boardBase, t.bgRaised, 0.4)!,
          stampBody: t.textPrimary,
          stampBodyHi: t.textSecondary,
          sealGlyph: _sealGlyph,
        ),
      );
    }

    String caption;
    switch (widget.state) {
      case SyncVisualState.success:
        caption = t.uppercaseLabels ? 'SEALED' : 'Sealed';
      case SyncVisualState.transferring:
        caption = t.uppercaseLabels
            ? 'INSCRIBING THE PAD…'
            : 'Inscribing the pad…';
      default:
        caption = t.uppercaseLabels
            ? 'OPENING THE SCROLL…'
            : 'Opening the scroll…';
    }

    return Container(
      width: double.infinity,
      height: 170,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border, width: t.borderWidth),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _ticker == null
                ? paint()
                : AnimatedBuilder(
                    animation: _ticker!,
                    builder: (context, _) => paint(),
                  ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                caption,
                style: t.dataMono.copyWith(color: t.textSecondary, fontSize: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Cached seal glyph (laid out once; tinted at paint time).
  static final TextPainter _sealGlyph = TextPainter(
    text: const TextSpan(
      text: _sealKanji,
      style: TextStyle(
        fontFamily: 'ShipporiMincho',
        fontWeight: FontWeight.w900,
        fontSize: 30,
        height: 1.0,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

class _ScrollSealPainter extends CustomPainter {
  final double open; // 0..1 unrolled fraction
  final double stampT; // 0..1 stamp sequence (0 = not started)
  final int timeMs;
  final bool reduceMotion;
  final Color paper, paperEdge, sumi, wash, seal, rod, rodHi;
  final Color stampBody, stampBodyHi;
  final TextPainter sealGlyph;

  _ScrollSealPainter({
    required this.open,
    required this.stampT,
    required this.timeMs,
    required this.reduceMotion,
    required this.paper,
    required this.paperEdge,
    required this.sumi,
    required this.wash,
    required this.seal,
    required this.rod,
    required this.rodHi,
    required this.stampBody,
    required this.stampBodyHi,
    required this.sealGlyph,
  });

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 - 6;
    final paperH = 88.0;
    final top = cy - paperH / 2;
    final maxHalf = size.width / 2 - 26;
    final openHalf = math.max(5.0, maxHalf * open.clamp(0.0, 1.0));
    final xl = cx - openHalf;
    final xr = cx + openHalf;

    // --- paper sheet between the rollers ---
    final sheet = Rect.fromLTRB(xl, top, xr, top + paperH);
    canvas.drawRect(
      sheet.shift(const Offset(0, 3)),
      Paint()
        ..color = sumi.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
    );
    canvas.drawRect(sheet, Paint()..color = paper);

    // edge curl shading where paper rolls into each rod
    for (final ex in [xl, xr]) {
      final toward = ex == xl ? 1.0 : -1.0;
      final strip = Rect.fromLTWH(ex - (toward < 0 ? 10 : 0), top, 10, paperH);
      canvas.drawRect(
        strip,
        Paint()
          ..shader = LinearGradient(
            begin: ex == xl ? Alignment.centerLeft : Alignment.centerRight,
            end: ex == xl ? Alignment.centerRight : Alignment.centerLeft,
            colors: [sumi.withValues(alpha: 0.12), sumi.withValues(alpha: 0.0)],
          ).createShader(strip),
      );
    }

    // --- calligraphy, brushed on as the paper reveals (centre-out) ---
    canvas.save();
    canvas.clipRect(sheet);
    const spacing = 15.0;
    const colTop = 12.0; // inset from paper top/bottom
    final colH = paperH - colTop * 2;
    const revealDist = 28.0; // unroll distance over which a column finishes
    for (double dx = 12; dx <= openHalf; dx += spacing) {
      final fresh = ((openHalf - dx) / revealDist).clamp(0.0, 1.0);
      if (fresh <= 0) continue;
      // both sides of centre
      _column(
        canvas,
        cx + dx,
        top + colTop,
        colH,
        fresh,
        ((dx / spacing).round()) * 2,
      );
      _column(
        canvas,
        cx - dx,
        top + colTop,
        colH,
        fresh,
        ((dx / spacing).round()) * 2 + 1,
      );
    }
    canvas.restore();

    // --- wooden rollers at each open edge ---
    _rodAt(canvas, xl, cy, paperH);
    _rodAt(canvas, xr, cy, paperH);

    // --- the seal / hanko stamp on success ---
    if (stampT > 0) {
      _paintStamp(canvas, Offset(cx, cy), paperH);
    }
  }

  void _column(
    Canvas canvas,
    double x,
    double yTop,
    double h,
    double fresh,
    int seed,
  ) {
    // A freshly revealed column is mid-stroke (written top-down): clip its height.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(x - 7, yTop, 14, h * fresh));
    final rand = math.Random(seed * 977 + 13);
    final strokes = 2 + rand.nextInt(2);
    final paint = Paint()
      ..color = sumi.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (int s = 0; s < strokes; s++) {
      final sx = x + (rand.nextDouble() - 0.5) * 6;
      final segTop = yTop + rand.nextDouble() * h * 0.2;
      final segH = h * (0.45 + rand.nextDouble() * 0.5);
      final wig = 1.5 + rand.nextDouble() * 2.5;
      final ph = rand.nextDouble() * math.pi * 2;
      final path = Path()..moveTo(sx, segTop);
      for (double yy = 0; yy <= segH; yy += 5) {
        path.lineTo(
          sx + math.sin(yy / segH * math.pi * 1.4 + ph) * wig,
          segTop + yy,
        );
      }
      canvas.drawPath(path, paint);
      // an occasional horizontal tick to read as a character
      if (rand.nextBool()) {
        final ty = segTop + segH * (0.2 + rand.nextDouble() * 0.5);
        canvas.drawLine(Offset(sx - 3, ty), Offset(sx + 4, ty), paint);
      }
    }
    canvas.restore();
  }

  void _rodAt(Canvas canvas, double x, double cy, double paperH) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, cy), width: 8, height: paperH + 18),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      rect.shift(const Offset(0, 2)),
      Paint()
        ..color = sumi.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );
    canvas.drawRRect(rect, Paint()..color = rod);
    // highlight stripe
    canvas.drawLine(
      Offset(x - 1.5, cy - paperH / 2 - 4),
      Offset(x - 1.5, cy + paperH / 2 + 4),
      Paint()
        ..color = rodHi.withValues(alpha: 0.7)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintStamp(Canvas canvas, Offset center, double paperH) {
    // Timeline within stampT: 0–0.28 drop, 0.28–0.42 bite (squash + imprint +
    // particles), 0.42–0.78 lift & fade, 0.78–1 settle. The vermilion imprint
    // appears at the bite and stays.
    final imprintIn = stampT < 0.28
        ? 0.0
        : ((stampT - 0.28) / 0.14).clamp(0.0, 1.0);

    // 1) the settled vermilion seal imprint (rounded square + 結)
    if (imprintIn > 0) {
      final half = 22.0;
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: half * 2, height: half * 2),
        const Radius.circular(5),
      );
      // soft ink bleed
      canvas.drawRRect(
        r,
        Paint()
          ..color = seal.withValues(alpha: 0.10 * imprintIn)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..color = seal.withValues(alpha: 0.9 * imprintIn)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
      _tintGlyph(
        canvas,
        sealGlyph,
        center - Offset(sealGlyph.width / 2, sealGlyph.height / 2),
        seal.withValues(alpha: 0.92 * imprintIn),
      );
    }

    // 2) particle burst at the bite
    if (!reduceMotion && stampT >= 0.28 && stampT < 0.62) {
      final tp = ((stampT - 0.28) / 0.34).clamp(0.0, 1.0);
      final eased = 1 - math.pow(1 - tp, 3).toDouble();
      final paint = Paint()..style = PaintingStyle.fill;
      for (int i = 0; i < 11; i++) {
        final a = (i / 11) * 2 * math.pi + 0.3 * (i % 3);
        final v = 18.0 + 7.0 * (i % 4);
        paint.color = seal.withValues(alpha: (1 - eased) * 0.8);
        canvas.drawCircle(
          center + Offset(math.cos(a), math.sin(a)) * v * eased,
          2.4 * (1 - eased),
          paint,
        );
      }
    }

    // 3) the descending stamp block (drop → squash → lift & fade)
    if (reduceMotion) return;
    double blockOpacity = 0, ty = 0, sx = 1, sy = 1, rot = -0.035;
    if (stampT < 0.28) {
      final tD = stampT / 0.28;
      final e = const Cubic(0.5, 0.0, 1.0, 1.0).transform(tD);
      blockOpacity = (tD * 2).clamp(0.0, 1.0);
      ty = _lerp(-130, 0, e);
      final sc = _lerp(2.2, 1.0, e);
      sx = sc;
      sy = sc;
      rot = _lerp(0.26, -0.035, e);
    } else if (stampT < 0.42) {
      final tS = (stampT - 0.28) / 0.14;
      blockOpacity = 1.0;
      sx = _lerp(1.0, 1.04, tS);
      sy = _lerp(1.0, 0.94, tS);
      ty = _lerp(0, 3, tS);
    } else if (stampT < 0.78) {
      final tL = (stampT - 0.42) / 0.36;
      final e = const Cubic(0.2, 0.8, 0.2, 1.0).transform(tL);
      blockOpacity = (1 - Curves.easeIn.transform(tL)).clamp(0.0, 1.0);
      ty = _lerp(3, -120, e);
      final sc = _lerp(1.0, 1.3, e);
      sx = sc;
      sy = sc;
      rot = _lerp(-0.035, 0.3, e);
    }

    if (blockOpacity <= 0) return;
    canvas.save();
    canvas.translate(center.dx, center.dy + ty);
    canvas.rotate(rot);
    canvas.scale(sx, sy);
    final block = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 50, height: 50),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      block.shift(const Offset(2, 4)),
      Paint()
        ..color = sumi.withValues(alpha: 0.35 * blockOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );
    canvas.drawRRect(
      block,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            stampBodyHi.withValues(alpha: blockOpacity),
            stampBody.withValues(alpha: blockOpacity),
          ],
        ).createShader(block.outerRect),
    );
    // little handle nub on top
    canvas.drawCircle(
      const Offset(0, -19),
      3.0,
      Paint()..color = rodHi.withValues(alpha: blockOpacity),
    );
    canvas.restore();
  }

  void _tintGlyph(Canvas canvas, TextPainter tp, Offset at, Color color) {
    canvas.saveLayer(
      Rect.fromLTWH(at.dx - 1, at.dy - 1, tp.width + 2, tp.height + 2),
      Paint(),
    );
    tp.paint(canvas, at);
    canvas.drawRect(
      Rect.fromLTWH(at.dx - 1, at.dy - 1, tp.width + 2, tp.height + 2),
      Paint()
        ..color = color
        ..blendMode = BlendMode.srcIn,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScrollSealPainter old) =>
      old.open != open ||
      old.stampT != stampT ||
      old.timeMs != timeMs ||
      old.sumi != sumi ||
      old.seal != seal;
}
