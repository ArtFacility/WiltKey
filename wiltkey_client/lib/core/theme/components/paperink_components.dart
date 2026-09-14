import 'dart:ui' as ui;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../wiltkey_components.dart';
import '../wk.dart';
import 'effects/paperink_unlock.dart';
import 'effects/paperink_sync_visual.dart';
import 'effects/paperink_nuke_flood.dart';
import 'effects/paperink_voice_playback.dart';

/// Paper & Ink component set: hand-drawn Ensō budget indicators, minimal hanko
/// keypad badges, and delegated screen overlays.
class PaperinkComponents
    with VoiceScrubberDefaults
    implements WiltkeyComponents {
  const PaperinkComponents();

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

    // Double the fractions in split mode just like garden does, so each half
    // represents its own 0..1 range.
    final double ours = split
        ? (ourFraction * 2).clamp(0.0, 1.0)
        : ourFraction.clamp(0.0, 1.0);
    final double theirs = split
        ? (theirFraction * 2).clamp(0.0, 1.0)
        : ourFraction.clamp(0.0, 1.0);

    return EnsoIndicator(
      ourFraction: ours,
      theirFraction: theirs,
      isWilted: isWilted,
      split: split,
      size: size,
      semanticLabel: semanticLabel,
    );
  }

  @override
  Widget groupBudgetIndicator({
    required List<MemberBudget> members,
    int emptySlots = 0,
  }) {
    return _PaperinkGroupBudget(members: members, emptySlots: emptySlots);
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: spec.color.withValues(alpha: 0.05),
        border: Border.all(
          color: spec.color.withValues(alpha: 0.5),
          width: t.borderWidth,
        ),
        borderRadius: BorderRadius.circular(t.radiusControl), // 3
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spec.icon != null) ...[
            Icon(spec.icon, size: 12, color: spec.color),
            const SizedBox(width: 4),
          ],
          Text(
            t.uppercaseLabels ? spec.text.toUpperCase() : spec.text,
            style: t.badgeLabel.copyWith(
              color: spec.color,
              fontWeight: FontWeight.w500,
            ),
          ),
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
        Text(
          t.uppercaseLabels ? text.toUpperCase() : text,
          style: t.screenTitle,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            t.uppercaseLabels ? subtitle.toUpperCase() : subtitle,
            style: t.sectionLabel,
          ),
        ],
      ],
    );
  }

  @override
  Widget ambientBackground({required Widget child}) {
    // Flat warm paper background (drawn by scaffoldBackgroundColor).
    return child;
  }

  @override
  Widget syncVisual({
    required SyncVisualState state,
    double progress = 0,
    List<SyncBlip> blips = const [],
    List<String> log = const [],
    Color? accent,
  }) {
    // Scanning = the pinned-ofuda board; connect/transfer/success = the
    // unrolling handscroll that gets sealed.
    if (state == SyncVisualState.scanning) {
      return PaperinkSyncVisual(blips: blips, log: log);
    }
    return PaperinkSyncScroll(state: state, progress: progress, accent: accent);
  }

  @override
  Widget pinProgress(
    BuildContext context, {
    required int entered,
    required int length,
    required bool error,
  }) {
    final t = context.wk;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final hasDigit = index < entered;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 14,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(3),
            color: hasDigit
                ? (error ? t.danger : t.action)
                : Colors.transparent,
            border: Border.all(
              color: error ? t.danger : (hasDigit ? t.action : t.border),
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget unlockTransition({required VoidCallback onDone}) =>
      PaperinkUnlockSequence(onDone: onDone);

  @override
  void precacheUnlock(BuildContext context) => PaperinkUnlockSequence.warmUp();

  @override
  Widget profileBackdrop({
    required Widget child,
    int seed = 0,
  }) => _PaperinkProfileBackdrop(seed: seed, child: child);

  @override
  Widget nukeOverlay({required VoidCallback onDone, ui.Image? screen}) =>
      PaperinkNukeFlood(onDone: onDone);

  // Shadows the VoiceScrubberDefaults mixin: the bespoke unrolling handscroll.
  @override
  Widget voiceScrubber({
    required double progress,
    required bool isPlaying,
    int seed = 0,
    ValueChanged<double>? onSeek,
    Color? accent,
    List<int>? waveform,
  }) => PaperinkVoicePlayback(
    progress: progress,
    isPlaying: isPlaying,
    seed: seed,
    onSeek: onSeek,
    accent: accent,
  );
}

/// Renders the circular single-breath brush circle (Ensō).
class EnsoIndicator extends StatelessWidget {
  final double ourFraction;
  final double theirFraction;
  final bool isWilted;
  final bool split;
  final double size;
  final String? semanticLabel;

  const EnsoIndicator({
    super.key,
    required this.ourFraction,
    required this.theirFraction,
    required this.isWilted,
    required this.split,
    required this.size,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: ourFraction),
          duration: t.motionBudget,
          curve: Curves.easeOutCubic,
          builder: (context, animOurs, _) {
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: theirFraction),
              duration: t.motionBudget,
              curve: Curves.easeOutCubic,
              builder: (context, animTheirs, _) {
                return CustomPaint(
                  painter: _EnsoPainter(
                    ourFraction: animOurs,
                    theirFraction: animTheirs,
                    isWilted: isWilted,
                    split: split,
                    sumiColor: t.budgetFill,
                    washColor: t.budgetFillPeer,
                    faintColor: t.budgetLow,
                    emptyColor: t.budgetEmpty,
                    wiltedColor: t.budgetWilted,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EnsoPainter extends CustomPainter {
  final double ourFraction;
  final double theirFraction;
  final bool isWilted;
  final bool split;

  final Color sumiColor;
  final Color washColor;
  final Color faintColor;
  final Color emptyColor;
  final Color wiltedColor;

  _EnsoPainter({
    required this.ourFraction,
    required this.theirFraction,
    required this.isWilted,
    required this.split,
    required this.sumiColor,
    required this.washColor,
    required this.faintColor,
    required this.emptyColor,
    required this.wiltedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Design viewBox is 40x40.
    final scale = size.width / 40.0;
    canvas.scale(scale);

    const double radius = 14.5;
    const Offset center = Offset(20, 20);

    if (isWilted) {
      // Draw dried/ghost full circle using a dashed sumi lines style.
      final ghostPaint = Paint()
        ..color = wiltedColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      _drawDashedCircle(canvas, center, radius, ghostPaint);
      return;
    }

    // Ours: the outer ensō ring — full sumi ink drying toward the tail.
    _ring(
      canvas,
      center,
      radius,
      ourFraction,
      ink: sumiColor,
      dry: washColor,
      wBase: 4.0,
      wTip: 1.5,
      trackWidth: 2.0,
    );

    // Peer: a concentric *inner* ring in diluted (wash) ink. Two strokes in one
    // circle would collide, so the second budget reads as a smaller ring inside
    // ours instead of splitting the same arc.
    if (split) {
      _ring(
        canvas,
        center,
        radius - 5.3,
        theirFraction,
        ink: washColor,
        dry: faintColor,
        wBase: 3.0,
        wTip: 1.1,
        trackWidth: 1.4,
      );
    }
  }

  /// One ensō stroke: a faint full track plus the brushed arc up to [fraction],
  /// tapering in width and drying in colour toward its tail (a single breath).
  void _ring(
    Canvas canvas,
    Offset center,
    double radius,
    double fraction, {
    required Color ink,
    required Color dry,
    required double wBase,
    required double wTip,
    required double trackWidth,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = emptyColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackWidth,
    );

    final f = fraction.clamp(0.0, 1.0);
    if (f <= 0) return;

    const int segments = 30;
    final double segmentSweep = (2 * math.pi * f) / segments;
    final Color tail = f < 0.2 ? faintColor : dry;
    for (int i = 0; i < segments; i++) {
      final double t = i / segments;
      final segPaint = Paint()
        ..color = Color.lerp(ink, tail, t)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = wBase - (wBase - wTip) * t
        ..strokeCap = (i == 0 || i == segments - 1)
            ? StrokeCap.round
            : StrokeCap.square;
      final double startAngle = -math.pi / 2 + i * segmentSweep;
      canvas.drawArc(rect, startAngle, segmentSweep + 0.01, false, segPaint);
    }
  }

  void _drawDashedCircle(Canvas canvas, Offset c, double r, Paint paint) {
    const int dashes = 12;
    const double gap = 0.4;
    final sweep = (2 * math.pi / dashes) * (1 - gap);
    final rect = Rect.fromCircle(center: c, radius: r);
    for (int i = 0; i < dashes; i++) {
      final start = (2 * math.pi / dashes) * i;
      canvas.drawArc(rect, start, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(_EnsoPainter old) =>
      old.ourFraction != ourFraction ||
      old.theirFraction != theirFraction ||
      old.isWilted != isWilted ||
      old.split != split ||
      old.sumiColor != sumiColor ||
      old.washColor != washColor ||
      old.faintColor != faintColor ||
      old.emptyColor != emptyColor ||
      old.wiltedColor != wiltedColor;
}

/// Renders a row of mini Ensō indicators, one for each group member.
class _PaperinkGroupBudget extends StatelessWidget {
  final List<MemberBudget> members;
  final int emptySlots;

  const _PaperinkGroupBudget({required this.members, required this.emptySlots});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final indicators = <Widget>[];

    for (final m in members) {
      Color fill;
      if (m.isSelf) {
        fill = t.budgetFill;
      } else if (m.isHost) {
        fill = t.budgetFillPeer;
      } else {
        fill = memberPaletteColor(m.keyHash);
      }

      indicators.add(
        SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(
            painter: _EnsoPainter(
              ourFraction: m.fraction,
              theirFraction: 0,
              isWilted: m.isWilted,
              split: false,
              sumiColor: fill,
              washColor: fill.withValues(alpha: 0.6),
              faintColor: t.budgetLow,
              emptyColor: t.budgetEmpty,
              wiltedColor: t.budgetWilted,
            ),
          ),
        ),
      );
    }

    for (int i = 0; i < emptySlots; i++) {
      indicators.add(
        SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(
            painter: _EnsoPainter(
              ourFraction: 0,
              theirFraction: 0,
              isWilted: true,
              split: false,
              sumiColor: t.border,
              washColor: t.border,
              faintColor: t.border,
              emptyColor: t.border,
              wiltedColor: t.border,
            ),
          ),
        ),
      );
    }

    return Wrap(spacing: 6, runSpacing: 6, children: indicators);
  }
}

// Paperink profile backdrop: hanging washi paper slips (ofuda) pinned to the
// backdrop like talismans. Some sway gently in the draft.
// Reuses Slip/SlipRender/OfudaPainter from paperink_sync_visual.dart.
class _PaperinkProfileBackdrop extends StatefulWidget {
  final Widget child;
  final int seed;

  const _PaperinkProfileBackdrop({required this.child, required this.seed});

  @override
  State<_PaperinkProfileBackdrop> createState() => _PaperinkProfileBackdropState();
}

class _PaperinkProfileBackdropState extends State<_PaperinkProfileBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  late final List<Slip> _slips;
  late final Stopwatch _clock;

  @override
  void initState() {
    super.initState();
    final r = math.Random(widget.seed);
    const int count = 8;
    _slips = List.generate(count, (i) {
      // 2-3 columns spread across the board
      final double col = (i % 3).toDouble();
      final double row = (i ~/ 3).toDouble();
      final double rx = 0.08 + col * 0.38 + (r.nextDouble() - 0.5) * 0.08;
      final double strength = (0.15 + row * 0.35 + (r.nextDouble() - 0.5) * 0.1).clamp(0.05, 0.95);
      final double w = 64 + r.nextDouble() * 24;
      final double h = 95 + r.nextDouble() * 32;
      final bool peer = r.nextBool();
      final blip = SyncBlip(
        id: 'profile_slip_$i',
        strength: strength,
        angle: (r.nextDouble() - 0.5) * 0.5,
        isWiltkey: peer,
        isNear: true,
        isGroup: false,
      );
      return Slip(
        blip,
        0,
        strength: strength,
        rx: rx.clamp(0.05, 0.95),
        yJitter: (r.nextDouble() - 0.5) * 0.2,
        swayPhase: r.nextDouble() * math.pi * 2,
        rotPhase: r.nextDouble() * math.pi * 2,
        flutterPhase: r.nextDouble() * math.pi * 2,
        w: w,
        h: h,
        peer: peer,
        glyph: _makeGlyph(peer, r),
      );
    });

    _clock = Stopwatch()..start();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  TextPainter _makeGlyph(bool peer, math.Random r) {
    const genericKanji = ['音', '影', '遠', '客', '風', '月', '心', '花'];
    const keyKanji = '鍵';
    final text = peer ? keyKanji : genericKanji[r.nextInt(genericKanji.length)];
    return TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: 'NotoSansJP',
          fontSize: 26,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
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
    for (final s in _slips) {
      s.glyph.dispose();
    }
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final reduceMotion = context.reduceMotion;

    Widget buildBoard() => CustomPaint(
      painter: OfudaPainter(
        slips: _slips.map((s) => s.toRender(_clock.elapsedMilliseconds, reduceMotion)).toList(),
        timeMs: _clock.elapsedMilliseconds,
        reduceMotion: reduceMotion,
        paper: t.surface,
        paperEdge: t.border,
        sumi: t.textPrimary,
        wash: t.bgRaised,
        dust: t.textTertiary,
        seal: t.danger,
        boardBase: t.bg,
        boardGrain: t.border,
      ),
      size: Size.infinite,
    );

    return Stack(
      children: [
        ColoredBox(color: t.bg),
        Positioned.fill(
          child: reduceMotion
              ? buildBoard()
              : AnimatedBuilder(
                  animation: _ticker,
                  builder: (_, _) => buildBoard(),
                ),
        ),
        widget.child,
      ],
    );
  }
}

// Profile-specific Slip render helper (pinned at rest with gentle flutter).
extension _ProfileSlipExt on Slip {
  SlipRender toRender(int timeMs, bool reduceMotion) {
    return SlipRender(
      slip: this,
      fallPhase: 1.0, // Settled on the board
      stiffen: reduceMotion ? 1.0 : 0.82, // Pin holds top, bottom flutters
      pinGrow: 1.0, // Red pin visible
      recoil: 0,
      fade: 1.0,
    );
  }
}
