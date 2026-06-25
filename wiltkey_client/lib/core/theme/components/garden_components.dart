import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../wiltkey_components.dart';
import '../wk.dart';
import 'petal_flower.dart';
import 'effects/garden_sync_visual.dart';
import 'effects/garden_pin_visuals.dart';
import 'effects/garden_nuke_wilt.dart';

/// Dusk Garden component set: petal flowers, soft pills, serif titles, and an
/// ambient backdrop with gradients + drifting fireflies.
class GardenComponents implements WiltkeyComponents {
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
  Widget nukeOverlay({required VoidCallback onDone}) =>
      GardenNukeWilt(onDone: onDone);

  @override
  void precacheUnlock(BuildContext context) {} // cheap first frame; nothing to warm
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
