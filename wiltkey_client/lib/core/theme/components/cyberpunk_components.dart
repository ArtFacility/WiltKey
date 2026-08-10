import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../wiltkey_components.dart';
import '../wk.dart';
import 'segmented_charge_bar.dart';
import 'effects/cyberpunk_sync_visual.dart';
import 'effects/cyberpunk_unlock.dart';
import 'effects/cyberpunk_nuke_purge.dart';
import 'effects/cyberpunk_voice_playback.dart';

/// Cyberpunk component set: segmented charge bars, bordered caps chips, flat bg.
class CyberpunkComponents
    with VoiceScrubberDefaults
    implements WiltkeyComponents {
  const CyberpunkComponents();

  @override
  Widget budgetIndicator({
    required double ourFraction,
    double theirFraction = 0,
    required bool isWilted,
    bool split = false,
    BudgetIndicatorVariant variant = BudgetIndicatorVariant.listRow,
    String? semanticLabel,
  }) {
    // The segmented bar already reads fractions as a share of the whole pad and
    // fills from both ends, so it renders correctly for both the split (1:1) and
    // single (group) cases without branching on [split].
    // SegmentedChargeBar fills its width (LayoutBuilder + mainAxisSize.max), so
    // in a trailing row slot it MUST be width-bounded or it throws on an
    // unbounded-width constraint. listRow/chatHeader are compact trailing
    // glyphs (parity with the garden flower); detail is full-width and bounded
    // by its caller's column.
    final bar = SegmentedChargeBar(
      percentage: ourFraction,
      theirPercentage: theirFraction,
      isWilted: isWilted,
      totalSegments: variant == BudgetIndicatorVariant.detail ? 16 : 8,
    );
    final Widget sized = switch (variant) {
      BudgetIndicatorVariant.listRow => SizedBox(width: 60, child: bar),
      BudgetIndicatorVariant.chatHeader => SizedBox(width: 72, child: bar),
      BudgetIndicatorVariant.detail => bar,
    };
    return Semantics(label: semanticLabel, child: sized);
  }

  @override
  Widget groupBudgetIndicator({
    required List<MemberBudget> members,
    int emptySlots = 0,
  }) {
    final mapped = members
        .map(
          (m) => <String, dynamic>{
            'remaining': m.isWilted
                ? 0
                : (m.fraction.clamp(0.0, 1.0) * 10000).round(),
            'max': 10000,
            'keyHash': m.keyHash,
            'isSelf': m.isSelf,
            'isHost': m.isHost,
          },
        )
        .toList();
    return GroupChargeBar(members: mapped, emptySlots: emptySlots);
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: spec.color.withValues(alpha: 0.1),
        border: Border.all(color: spec.color.withValues(alpha: 0.4), width: 1),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spec.icon != null) ...[
            Icon(spec.icon, size: 11, color: spec.color),
            const SizedBox(width: 4),
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
    // Cyberpunk is flat; the scaffold bg color carries it. Room here later for
    // scanlines/grid without touching call sites.
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
    // Only the scan phase has a bespoke visual (the radar). The connect/transfer/
    // success phases still use the inline progress/success cards on the screens.
    if (state == SyncVisualState.scanning) {
      return CyberpunkSyncVisual(blips: blips, log: log);
    }
    return const SizedBox.shrink();
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
          duration: const Duration(milliseconds: 100),
          width: 14,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasDigit
                ? (error ? t.danger : t.action)
                : Colors.transparent,
            border: Border.all(
              color: error ? t.danger : (hasDigit ? t.action : t.budgetEmpty),
              width: 2.0,
            ),
            boxShadow: hasDigit && !error ? t.glow(t.action) : null,
          ),
        );
      }),
    );
  }

  @override
  Widget unlockTransition({required VoidCallback onDone}) =>
      CyberpunkUnlockSequence(onDone: onDone);

  @override
  Widget nukeOverlay({required VoidCallback onDone}) =>
      CyberpunkNukePurge(onDone: onDone);

  @override
  void precacheUnlock(BuildContext context) {} // cheap first frame; nothing to warm

  @override
  Widget profileBackdrop({
    required Widget child,
    int seed = 0,
  }) => _CyberpunkProfileBackdrop(seed: seed, child: child);

  // Shadows the VoiceScrubberDefaults mixin: the bespoke lit-up soundwave.
  @override
  Widget voiceScrubber({
    required double progress,
    required bool isPlaying,
    int seed = 0,
    ValueChanged<double>? onSeek,
    Color? accent,
  }) => CyberpunkVoicePlayback(
    progress: progress,
    isPlaying: isPlaying,
    seed: seed,
    onSeek: onSeek,
    accent: accent,
  );
}

// Cyberpunk profile backdrop: falling 0/1 rain columns (Matrix-style).
class _CyberpunkProfileBackdrop extends StatefulWidget {
  final Widget child;
  final int seed;

  const _CyberpunkProfileBackdrop({required this.child, required this.seed});

  @override
  State<_CyberpunkProfileBackdrop> createState() => _CyberpunkProfileBackdropState();
}

class _CyberpunkProfileBackdropState extends State<_CyberpunkProfileBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  late final List<_RainColumn> _columns;

  @override
  void initState() {
    super.initState();
    final r = math.Random(widget.seed);
    _columns = List.generate(18, (i) {
      return _RainColumn(
        x: r.nextDouble(),
        speed: 0.3 + r.nextDouble() * 0.7,
        length: 12 + r.nextInt(10),
        charSet: r.nextBool()
            ? '01'
            : '01アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン',
      );
    });

    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    if (!context.reduceMotion) {
      _ticker.forward();
    }
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

    return Stack(
      children: [
        CustomPaint(
          painter: _RainPainter(
            columns: _columns,
            time: _ticker.value,
            reduceMotion: reduceMotion,
            color: t.action.withValues(alpha: 0.15),
            highlightColor: t.action.withValues(alpha: 0.4),
          ),
          size: Size.infinite,
        ),
        widget.child,
      ],
    );
  }
}

class _RainColumn {
  final double x;
  final double speed;
  final int length;
  final String charSet;

  const _RainColumn({
    required this.x,
    required this.speed,
    required this.length,
    required this.charSet,
  });

  int charAt(int row, double time) {
    final idx = ((time * speed * 60 + row * 3) % charSet.length).toInt();
    return charSet.codeUnitAt(idx);
  }
}

class _RainPainter extends CustomPainter {
  final List<_RainColumn> columns;
  final double time;
  final bool reduceMotion;
  final Color color;
  final Color highlightColor;

  _RainPainter({
    required this.columns,
    required this.time,
    required this.reduceMotion,
    required this.color,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    final double colWidth = size.width / (columns.length + 1);
    final double charHeight = 18.0;
    final int maxRows = (size.height / charHeight).ceil() + 2;

    for (int i = 0; i < columns.length; i++) {
      final col = columns[i];
      final double x = (i + 0.5) * colWidth;

      for (int row = 0; row < maxRows; row++) {
        final double y = size.height -
            ((time * col.speed * size.height + row * charHeight) %
                (size.height + charHeight * col.length));

        if (y < -charHeight || y > size.height + charHeight) continue;

        final int charCode = col.charAt(row, time);
        final bool isHead = row == 0 && !reduceMotion;

        textPainter.text = TextSpan(
          text: String.fromCharCode(charCode),
          style: TextStyle(
            fontFamily: 'IBMPlexMono',
            fontSize: reduceMotion ? 13 : 14,
            color: isHead ? highlightColor : color,
            fontWeight: isHead ? FontWeight.bold : FontWeight.normal,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter old) =>
      old.time != time || old.reduceMotion != reduceMotion;
}
