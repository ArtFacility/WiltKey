import 'package:flutter/material.dart';
import '../wiltkey_components.dart';
import '../wk.dart';
import 'segmented_charge_bar.dart';
import 'effects/cyberpunk_sync_visual.dart';
import 'effects/cyberpunk_unlock.dart';
import 'effects/cyberpunk_nuke_purge.dart';

/// Cyberpunk component set: segmented charge bars, bordered caps chips, flat bg.
class CyberpunkComponents implements WiltkeyComponents {
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
}
