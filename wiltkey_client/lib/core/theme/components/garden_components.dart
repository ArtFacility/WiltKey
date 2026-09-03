import 'dart:ui' as ui;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../wiltkey_components.dart';
import '../wk.dart';
import 'petal_flower.dart';
import 'effects/garden_sync_visual.dart';
import 'effects/garden_pin_visuals.dart';
import 'effects/garden_nuke_wilt.dart';
import 'effects/garden_voice_playback.dart';

/// Dusk Garden component set: petal flowers, soft pills, serif titles, and an
/// ambient backdrop with gradients + drifting fireflies.
class GardenComponents with VoiceScrubberDefaults implements WiltkeyComponents {
  /// Whether the ambient background draws fireflies (off by default under
  /// reduce-motion; this flag lets a future "calm" sub-theme disable them too).
  final bool fireflies;

  const GardenComponents({this.fireflies = true});

  @override
  Widget budgetIndicator({
    required double ourFraction,
    double theirFraction = 0,
    required bool isWilted,
    bool split = false,
    BudgetIndicatorVariant variant = BudgetIndicatorVariant.listRow,
    String? semanticLabel,
  }) {
    final double size = switch (variant) {
      BudgetIndicatorVariant.listRow => 36,
      BudgetIndicatorVariant.chatHeader => 38,
      BudgetIndicatorVariant.detail => 72,
    };
    return _GardenBudget(
      ourFraction: ourFraction,
      theirFraction: theirFraction,
      split: split,
      isWilted: isWilted,
      size: size,
      semanticLabel: semanticLabel,
    );
  }

  @override
  Widget groupBudgetIndicator({
    required List<MemberBudget> members,
    int emptySlots = 0,
  }) {
    return _GardenGroupBudget(members: members, emptySlots: emptySlots);
  }

  @override
  Widget statusBadge(
    BuildContext context,
    StatusBadgeKind kind, {
    String? label,
  }) {
    final t = context.wk;
    final spec = badgeSpec(t, kind, label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: spec.color.withValues(alpha: 0.07),
        border: Border.all(color: spec.color.withValues(alpha: 0.25), width: 1),
        borderRadius: BorderRadius.circular(t.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spec.icon != null) ...[
            Icon(spec.icon, size: 11, color: spec.color),
            const SizedBox(width: 5),
          ],
          Text(spec.text, style: t.badgeLabel.copyWith(color: spec.color)),
        ],
      ),
    );
  }

  @override
  Widget screenTitle(BuildContext context, String text, {String? subtitle}) {
    final t = context.wk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: t.screenTitle),
        if (subtitle != null) ...[
          const SizedBox(height: 1),
          Text(subtitle, style: t.bodySecondary),
        ],
      ],
    );
  }

  @override
  Widget ambientBackground({required Widget child}) {
    return _GardenAmbient(fireflies: fireflies, child: child);
  }

  @override
  Widget syncVisual({
    required SyncVisualState state,
    double progress = 0,
    List<SyncBlip> blips = const [],
    List<String> log = const [],
    Color? accent,
  }) {
    // Scan = the meadow; connect/transfer/success = the vine→bloom (its petals
    // take the optional accent, e.g. the group `identity` colour).
    if (state == SyncVisualState.scanning) {
      return GardenSyncVisual(blips: blips);
    }
    return GardenVineBloom(state: state, progress: progress, accent: accent);
  }

  @override
  Widget pinProgress(
    BuildContext context, {
    required int entered,
    required int length,
    required bool error,
  }) {
    return GardenPinProgress(entered: entered, length: length, error: error);
  }

  @override
  Widget unlockTransition({required VoidCallback onDone}) =>
      GardenUnlockBloom(onDone: onDone);

  @override
  Widget nukeOverlay({required VoidCallback onDone, ui.Image? screen}) =>
      GardenNukeWilt(onDone: onDone);

  @override
  void precacheUnlock(BuildContext context) {} // cheap first frame; nothing to warm

  @override
  Widget profileBackdrop({
    required Widget child,
    int seed = 0,
  }) => _GardenProfileBackdrop(seed: seed, child: child);

  // Shadows the VoiceScrubberDefaults mixin: the bespoke greening vine.
  @override
  Widget voiceScrubber({
    required double progress,
    required bool isPlaying,
    int seed = 0,
    ValueChanged<double>? onSeek,
    Color? accent,
  }) => GardenVoicePlayback(
    progress: progress,
    isPlaying: isPlaying,
    seed: seed,
    onSeek: onSeek,
    accent: accent,
  );
}

/// Reads tokens and renders the petal flower in one of two modes (see
/// [WiltkeyComponents.budgetIndicator] for `split`).
class _GardenBudget extends StatelessWidget {
  final double ourFraction;
  final double theirFraction;
  final bool split;
  final bool isWilted;
  final double size;
  final String? semanticLabel;

  const _GardenBudget({
    required this.ourFraction,
    required this.theirFraction,
    required this.split,
    required this.isWilted,
    required this.size,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    // The flower has 4 petals per side. In SPLIT (1:1) mode each side tracks one
    // half-lane: a lane's fraction is its share of the WHOLE pad (maxes ~0.5), so
    // we double it to fill that side's 4 petals — a fresh chat = full flower,
    // half each colour. In SINGLE (group) mode the fraction is already 0..1; we
    // mirror it across both sides in one colour for a full 8-petal health gauge.
    final double ours = split
        ? (ourFraction * 2).clamp(0.0, 1.0)
        : ourFraction.clamp(0.0, 1.0);
    final double theirs = split
        ? (theirFraction * 2).clamp(0.0, 1.0)
        : ourFraction.clamp(0.0, 1.0);
    final Color peerColor = split ? t.budgetFillPeer : t.budgetFill;
    return PetalFlower(
      ourFraction: ours,
      theirFraction: theirs,
      isWilted: isWilted,
      size: size,
      oursColor: t.budgetFill,
      peerColor: peerColor,
      centerFill: t.surfacePressed,
      centerStroke: t.positive,
      groundColor: t.textTertiary,
      lockedStroke: t.textTertiary,
      fallDuration: t.motionBudget,
      reduceMotion: context.reduceMotion,
      semanticLabel: semanticLabel,
    );
  }
}

/// A "flower bed": one mini single-color flower per group member.
class _GardenGroupBudget extends StatelessWidget {
  final List<MemberBudget> members;
  final int emptySlots;

  const _GardenGroupBudget({required this.members, required this.emptySlots});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final flowers = <Widget>[];
    for (final m in members) {
      Color petal;
      Color? ring;
      if (m.isSelf) {
        petal = t.identity;
      } else if (m.isHost) {
        petal = t.budgetFill;
        ring = t.budgetFill;
      } else {
        // Stable colour keyed by identity (matches this member's chat bubble).
        petal = memberPaletteColor(m.keyHash);
      }
      flowers.add(
        _MiniFlower(
          fraction: m.fraction,
          isWilted: m.isWilted,
          petalColor: petal,
          centerColor: t.surfacePressed,
          ringColor: ring,
          lockedStroke: t.textTertiary,
          size: 24,
        ),
      );
    }
    for (int i = 0; i < emptySlots; i++) {
      flowers.add(
        _MiniFlower(
          fraction: 0,
          isWilted: true,
          petalColor: t.textTertiary,
          centerColor: t.surface,
          ringColor: null,
          lockedStroke: t.border,
          size: 24,
        ),
      );
    }
    return Wrap(spacing: 6, runSpacing: 6, children: flowers);
  }
}

/// Single-color 8-petal mini flower for the group bed.
class _MiniFlower extends StatelessWidget {
  final double fraction;
  final bool isWilted;
  final Color petalColor;
  final Color centerColor;
  final Color? ringColor;
  final Color lockedStroke;
  final double size;

  const _MiniFlower({
    required this.fraction,
    required this.isWilted,
    required this.petalColor,
    required this.centerColor,
    required this.ringColor,
    required this.lockedStroke,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MiniFlowerPainter(
          shown: isWilted ? 0 : (fraction.clamp(0.0, 1.0) * 8).ceil(),
          petalColor: petalColor,
          centerColor: centerColor,
          ringColor: ringColor,
          lockedStroke: lockedStroke,
          isWilted: isWilted,
        ),
      ),
    );
  }
}

class _MiniFlowerPainter extends CustomPainter {
  final int shown;
  final Color petalColor;
  final Color centerColor;
  final Color? ringColor;
  final Color lockedStroke;
  final bool isWilted;

  // All 8 petals in 36-space.
  static const List<List<double>> _petals = [
    [18, 7.5, 3, 4.6, 0],
    [25.4, 10.6, 3, 4.6, 45],
    [28.5, 18, 4.6, 3, 0],
    [25.4, 25.4, 3, 4.6, -45],
    [18, 28.5, 3, 4.6, 0],
    [10.6, 25.4, 3, 4.6, 45],
    [7.5, 18, 4.6, 3, 0],
    [10.6, 10.6, 3, 4.6, -45],
  ];

  _MiniFlowerPainter({
    required this.shown,
    required this.petalColor,
    required this.centerColor,
    required this.ringColor,
    required this.lockedStroke,
    required this.isWilted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 36.0);
    final paint = Paint()..color = petalColor;
    for (int i = 0; i < shown && i < 8; i++) {
      final p = _petals[i];
      canvas.save();
      canvas.translate(p[0], p[1]);
      canvas.rotate(p[4] * math.pi / 180);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: p[2] * 2, height: p[3] * 2),
        paint,
      );
      canvas.restore();
    }
    if (isWilted) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = lockedStroke;
      canvas.drawCircle(const Offset(18, 18), 4.4, stroke);
    } else {
      canvas.drawCircle(
        const Offset(18, 18),
        4.4,
        Paint()..color = centerColor,
      );
      if (ringColor != null) {
        canvas.drawCircle(
          const Offset(18, 18),
          4.4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = ringColor!,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MiniFlowerPainter old) =>
      old.shown != shown || old.isWilted != isWilted;
}

/// Ambient backdrop: two soft radial gradients + optional drifting fireflies.
class _GardenAmbient extends StatefulWidget {
  final bool fireflies;
  final Widget child;
  const _GardenAmbient({required this.fireflies, required this.child});

  @override
  State<_GardenAmbient> createState() => _GardenAmbientState();
}

class _GardenAmbientState extends State<_GardenAmbient>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wantFireflies = widget.fireflies && !context.reduceMotion;
    if (wantFireflies && _ctrl == null) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 30),
      )..repeat();
    } else if (!wantFireflies && _ctrl != null) {
      _ctrl!.dispose();
      _ctrl = null;
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.6, -1.05),
          radius: 1.2,
          colors: [t.identity.withValues(alpha: 0.07), Colors.transparent],
          stops: const [0, 0.6],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.7, 1.05),
            radius: 1.2,
            colors: [t.action.withValues(alpha: 0.05), Colors.transparent],
            stops: const [0, 0.6],
          ),
        ),
        child: _ctrl == null
            ? widget.child
            : Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _ctrl!,
                        builder: (context, _) => CustomPaint(
                          painter: _FireflyPainter(_ctrl!.value, t.action),
                        ),
                      ),
                    ),
                  ),
                  widget.child,
                ],
              ),
      ),
    );
  }
}

class _FireflyPainter extends CustomPainter {
  final double progress;
  final Color color;
  static const int _count = 6;
  static final List<double> _seeds = List.generate(
    _count,
    (i) => (i * 0.61803398875) % 1.0,
  );

  _FireflyPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _count; i++) {
      final seed = _seeds[i];
      final phase = (progress + seed) % 1.0;
      final x =
          size.width *
          ((0.15 + 0.7 * ((seed * 7) % 1.0)) +
                  0.04 * math.sin(phase * 2 * math.pi))
              .clamp(0.0, 1.0);
      final y = size.height * (1.0 - phase);
      final twinkle = 0.04 + 0.04 * (0.5 + 0.5 * math.sin(phase * 6 * math.pi));
      canvas.drawCircle(
        Offset(x, y),
        1.6,
        Paint()..color = color.withValues(alpha: twinkle),
      );
    }
  }

  @override
  bool shouldRepaint(_FireflyPainter old) => old.progress != progress;
}

// Garden profile backdrop: a living dusk meadow with grounded grass, blooming
// flowers at the base, and delicate blossom petals drifting in the breeze.
class _GardenProfileBackdrop extends StatefulWidget {
  final Widget child;
  final int seed;

  const _GardenProfileBackdrop({required this.child, required this.seed});

  @override
  State<_GardenProfileBackdrop> createState() => _GardenProfileBackdropState();
}

class _GardenProfileBackdropState extends State<_GardenProfileBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  late final Stopwatch _clock;
  late final List<_GardenBlade> _backBlades;
  late final List<_GardenBlade> _frontBlades;
  late final List<_GardenProfileFlower> _flowers;
  late final List<_FloatingPetal> _petals;

  @override
  void initState() {
    super.initState();
    final r = math.Random(widget.seed);

    _backBlades = List.generate(24, (i) {
      return _GardenBlade(
        x: (i + r.nextDouble() * 0.5) / 24,
        height: 45 + r.nextDouble() * 40,
        phase: r.nextDouble() * math.pi * 2,
        width: 3.0 + r.nextDouble() * 2.5,
        shade: r.nextDouble(),
        lean: (r.nextDouble() - 0.5) * 0.4,
      );
    });

    _frontBlades = List.generate(14, (i) {
      return _GardenBlade(
        x: (i + r.nextDouble() * 0.6) / 14,
        height: 60 + r.nextDouble() * 50,
        phase: r.nextDouble() * math.pi * 2,
        width: 4.0 + r.nextDouble() * 3.0,
        shade: r.nextDouble(),
        lean: (r.nextDouble() - 0.5) * 0.5,
      );
    });

    _flowers = List.generate(8, (i) {
      return _GardenProfileFlower(
        x: 0.08 + (i / 8) * 0.84 + (r.nextDouble() - 0.5) * 0.08,
        stemHeight: 35 + r.nextDouble() * 35,
        scale: 0.75 + r.nextDouble() * 0.45,
        angle: r.nextDouble() * math.pi * 2,
        colorIndex: r.nextInt(4),
      );
    });

    _petals = List.generate(10, (i) {
      return _FloatingPetal(
        xInit: r.nextDouble(),
        yInit: 0.15 + r.nextDouble() * 0.65,
        speed: 0.4 + r.nextDouble() * 0.6,
        driftAmp: 15 + r.nextDouble() * 25,
        scale: 0.7 + r.nextDouble() * 0.5,
        rotPhase: r.nextDouble() * math.pi * 2,
        colorIndex: r.nextInt(3),
      );
    });

    _clock = Stopwatch()..start();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wantMotion = !context.reduceMotion;
    if (wantMotion && !_ticker.isAnimating) {
      _ticker.repeat();
    } else if (!wantMotion && _ticker.isAnimating) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final reduceMotion = context.reduceMotion;

    Widget buildMeadow() => CustomPaint(
      painter: _GardenProfilePainter(
        backBlades: _backBlades,
        frontBlades: _frontBlades,
        flowers: _flowers,
        petals: _petals,
        timeMs: _clock.elapsedMilliseconds,
        reduceMotion: reduceMotion,
        grass: t.positive,
        soil: t.bg,
        petalColors: [t.budgetFill, t.action, t.identity, t.surfacePressed],
        halo: t.action,
        center: t.surfacePressed,
      ),
      size: Size.infinite,
    );

    return Stack(
      children: [
        // Dusk garden atmosphere: rich dark greenish sky fading to deep fertile soil
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.bg,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF222B20), // Dark greenish dusk sky
                  Color(0xFF181D17), // Deep soil
                  Color(0xFF131711), // Root bed
                ],
                stops: [0.0, 0.65, 1.0],
              ),
            ),
          ),
        ),
        // Dusk lilac atmospheric glow (top-left)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.6, -0.9),
                radius: 1.3,
                colors: [
                  t.identity.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
        ),
        // Warm marigold earth glow (bottom-right)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.7, 0.9),
                radius: 1.2,
                colors: [
                  t.action.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6],
              ),
            ),
          ),
        ),
        // Living meadow with swaying grass, blooming flowers, and floating petals
        Positioned.fill(
          child: reduceMotion
              ? buildMeadow()
              : AnimatedBuilder(
                  animation: _ticker,
                  builder: (_, _) => buildMeadow(),
                ),
        ),
        widget.child,
      ],
    );
  }
}

class _GardenBlade {
  final double x;
  final double height;
  final double phase;
  final double width;
  final double shade;
  final double lean;

  const _GardenBlade({
    required this.x,
    required this.height,
    required this.phase,
    required this.width,
    required this.shade,
    required this.lean,
  });
}

class _GardenProfileFlower {
  final double x;
  final double stemHeight;
  final double scale;
  final double angle;
  final int colorIndex;

  const _GardenProfileFlower({
    required this.x,
    required this.stemHeight,
    required this.scale,
    required this.angle,
    required this.colorIndex,
  });
}

class _FloatingPetal {
  final double xInit;
  final double yInit;
  final double speed;
  final double driftAmp;
  final double scale;
  final double rotPhase;
  final int colorIndex;

  const _FloatingPetal({
    required this.xInit,
    required this.yInit,
    required this.speed,
    required this.driftAmp,
    required this.scale,
    required this.rotPhase,
    required this.colorIndex,
  });
}

class _GardenProfilePainter extends CustomPainter {
  final List<_GardenBlade> backBlades;
  final List<_GardenBlade> frontBlades;
  final List<_GardenProfileFlower> flowers;
  final List<_FloatingPetal> petals;
  final int timeMs;
  final bool reduceMotion;
  final Color grass;
  final Color soil;
  final List<Color> petalColors;
  final Color halo;
  final Color center;

  _GardenProfilePainter({
    required this.backBlades,
    required this.frontBlades,
    required this.flowers,
    required this.petals,
    required this.timeMs,
    required this.reduceMotion,
    required this.grass,
    required this.soil,
    required this.petalColors,
    required this.halo,
    required this.center,
  });

  double get _t => timeMs / 1000.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final baseY = size.height + 4.0;
    final gust = reduceMotion ? 0.0 : 0.5 + 0.5 * math.sin(_t * 0.7);

    // 1. Drifting blossom petals across the air
    if (!reduceMotion) {
      for (final p in petals) {
        final double prog = (_t * 0.08 * p.speed + p.xInit) % 1.0;
        final double x = (prog * (size.width + 80)) - 40;
        final double y = p.yInit * size.height + math.sin(_t * 1.2 + p.rotPhase) * p.driftAmp;
        final double rot = _t * 1.1 + p.rotPhase;

        final petalColor = petalColors[p.colorIndex % petalColors.length];
        final petalPaint = Paint()..color = petalColor.withValues(alpha: 0.35);

        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rot);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: 10.0 * p.scale,
            height: 5.5 * p.scale,
          ),
          petalPaint,
        );
        canvas.restore();
      }

      // Floating pollen sparkles
      for (int i = 0; i < 6; i++) {
        final seed = (i * 0.61803398875) % 1.0;
        final ph = (_t * 0.06 + seed) % 1.0;
        final x = size.width * (0.08 + 0.84 * ((seed * 7) % 1.0) + 0.03 * math.sin(ph * 2 * math.pi));
        final y = size.height * (0.88 - ph * 0.75);
        final tw = 0.06 + 0.08 * (0.5 + 0.5 * math.sin(ph * 6 * math.pi));
        canvas.drawCircle(Offset(x, y), 1.5, Paint()..color = halo.withValues(alpha: tw));
      }
    }

    // 2. Back grass blades
    for (final b in backBlades) {
      _drawBlade(
        canvas,
        size,
        b,
        baseY,
        Color.lerp(grass, soil, 0.35 + b.shade * 0.25)!,
        gust,
        0.55,
      );
    }

    // 3. Grounded flowers nestled in the meadow
    for (final f in flowers) {
      final double x = f.x * size.width;
      final double groundY = baseY;
      final double scale = f.scale;
      final Color pColor = petalColors[f.colorIndex % petalColors.length];

      final double stemSway = reduceMotion ? 0.0 : math.sin(_t * 0.9 + f.angle) * 3.0 * scale;
      final double bob = reduceMotion ? 0.0 : math.sin(_t * 1.4 + f.angle * 2) * 1.5 * scale;
      final double topX = x + stemSway;
      final double topY = groundY - f.stemHeight + bob;

      // Stem
      final stemPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * scale
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(grass, soil, 0.15)!.withValues(alpha: 0.75);
      canvas.drawPath(
        Path()
          ..moveTo(x, groundY)
          ..quadraticBezierTo(x + stemSway * 0.4, groundY - f.stemHeight * 0.5, topX, topY),
        stemPaint,
      );

      // Bloom: 6 petals
      final double petalLen = 6.0 * scale;
      final double petalW = 3.4 * scale;
      final petalPaint = Paint()..color = pColor.withValues(alpha: 0.85);

      for (int i = 0; i < 6; i++) {
        final double a = (i / 6) * math.pi * 2 + f.angle;
        canvas.save();
        canvas.translate(topX + math.cos(a) * petalLen * 0.55, topY + math.sin(a) * petalLen * 0.55);
        canvas.rotate(a);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: petalLen, height: petalW),
          petalPaint,
        );
        canvas.restore();
      }

      // Center disc
      canvas.drawCircle(Offset(topX, topY), 2.6 * scale, Paint()..color = center);
    }

    // 4. Front grass blades
    for (final b in frontBlades) {
      _drawBlade(
        canvas,
        size,
        b,
        baseY,
        Color.lerp(grass, halo, 0.15 * b.shade)!,
        gust,
        0.85,
      );
    }
  }

  void _drawBlade(
    Canvas canvas,
    Size size,
    _GardenBlade b,
    double baseY,
    Color color,
    double gust,
    double alpha,
  ) {
    final bx = b.x * size.width;
    final h = b.height;
    final sway = reduceMotion
        ? b.lean * h * 0.12
        : (b.lean + 0.18 * math.sin(_t * 1.1 + b.phase) * (0.6 + 0.8 * gust)) * h * 0.16;
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

  @override
  bool shouldRepaint(covariant _GardenProfilePainter old) =>
      old.timeMs != timeMs || old.reduceMotion != reduceMotion;
}
