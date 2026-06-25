import 'package:flutter/material.dart';
import '../wk.dart';
import '../wiltkey_components.dart';

/// The cyberpunk budget glyph: a row of segments that fill from both ends —
/// our charge from the left, the peer's from the right. Colors and glow come
/// from the active theme's tokens, so the same widget renders correctly under
/// any skin (it is the cyberpunk theme's `budgetIndicator`).
class SegmentedChargeBar extends StatelessWidget {
  final double percentage;
  final double theirPercentage;
  final int totalSegments;
  final bool isWilted;

  const SegmentedChargeBar({
    super.key,
    required this.percentage,
    this.theirPercentage = 0.0,
    this.totalSegments = 16,
    this.isWilted = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final double safePercentage = percentage.clamp(0.0, 1.0);
    final double safeTheirPercentage = theirPercentage.clamp(
      0.0,
      1.0 - safePercentage,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: safePercentage),
      duration: t.motionBudget,
      curve: Curves.easeOutCubic,
      builder: (context, animatedPercentage, child) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: safeTheirPercentage),
          duration: t.motionBudget,
          curve: Curves.easeOutCubic,
          builder: (context, animatedTheirPercentage, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                const double spacing = 3.0;
                final double segmentWidth =
                    (width - (spacing * (totalSegments - 1))) / totalSegments;

                final ourFilled = (animatedPercentage * totalSegments).round();
                final theirFilled = (animatedTheirPercentage * totalSegments)
                    .round();

                return Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(totalSegments, (index) {
                    final bool isOurFilled = index < ourFilled && !isWilted;
                    final bool isTheirFilled =
                        index >= (totalSegments - theirFilled) && !isWilted;

                    Color segmentColor;
                    if (isWilted) {
                      segmentColor = t.budgetWilted.withValues(alpha: 0.15);
                    } else if (isOurFilled) {
                      segmentColor = animatedPercentage < 0.2
                          ? t.budgetLow
                          : t.budgetFill;
                    } else if (isTheirFilled) {
                      segmentColor = animatedTheirPercentage < 0.2
                          ? t.budgetLow.withValues(alpha: 0.7)
                          : t.budgetFillPeer;
                    } else {
                      segmentColor = t.budgetEmpty;
                    }

                    return Container(
                      width: segmentWidth,
                      height: 10,
                      decoration: BoxDecoration(
                        color: segmentColor,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: (isOurFilled || isTheirFilled) && !isWilted
                            ? t.glow(segmentColor)
                            : null,
                      ),
                    );
                  }),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Renders the WHOLE group pad's lane capacity as one bar: one cell per lane
/// slot. Each occupied member cell is filled proportionally to that member's
/// remaining charge and color-coded per member; unassigned lane slots render as
/// dim "empty" cells so the group can see free space at a glance.
class GroupChargeBar extends StatelessWidget {
  /// Each entry: { 'remaining': int, 'max': int, 'isSelf': bool, 'isHost': bool }
  final List<Map<String, dynamic>> members;

  /// Number of unassigned (empty) lane slots remaining in the pad.
  final int emptySlots;

  const GroupChargeBar({super.key, required this.members, this.emptySlots = 0});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final int totalCells = members.length + (emptySlots > 0 ? emptySlots : 0);
    if (totalCells == 0) {
      return Container(
        height: 10,
        decoration: BoxDecoration(
          color: t.budgetEmpty,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }

    final List<Widget> cells = [];

    for (int i = 0; i < members.length; i++) {
      final m = members[i];
      final int remaining = (m['remaining'] as int?) ?? 0;
      final int maxBytes = (m['max'] as int?) ?? 0;
      final String keyHash = (m['keyHash'] as String?) ?? '';
      final bool isSelf = (m['isSelf'] as bool?) ?? false;
      final bool isHost = (m['isHost'] as bool?) ?? false;
      final bool wilted = remaining <= 0;
      final double pct = maxBytes > 0
          ? (remaining / maxBytes).clamp(0.0, 1.0)
          : 0.0;

      Color fill;
      if (wilted) {
        fill = t.budgetWilted;
      } else if (isSelf) {
        fill = t.budgetFill;
      } else if (isHost) {
        fill = t.identity;
      } else {
        // Stable colour keyed by identity (matches this member's chat bubble).
        fill = memberPaletteColor(keyHash);
      }

      cells.add(
        Expanded(
          child: _LaneCell(fillFraction: wilted ? 0.0 : pct, fillColor: fill),
        ),
      );
    }

    for (int i = 0; i < emptySlots; i++) {
      cells.add(
        Expanded(
          child: _LaneCell(
            fillFraction: 0.0,
            fillColor: t.budgetFill,
            isEmptySlot: true,
          ),
        ),
      );
    }

    final List<Widget> spaced = [];
    for (int i = 0; i < cells.length; i++) {
      spaced.add(cells[i]);
      if (i != cells.length - 1) spaced.add(const SizedBox(width: 3));
    }

    return Row(mainAxisSize: MainAxisSize.max, children: spaced);
  }
}

class _LaneCell extends StatelessWidget {
  final double fillFraction;
  final Color fillColor;
  final bool isEmptySlot;

  const _LaneCell({
    required this.fillFraction,
    required this.fillColor,
    this.isEmptySlot = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: t.budgetEmpty,
        borderRadius: BorderRadius.circular(2),
        border: isEmptySlot ? Border.all(color: t.border, width: 1) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: isEmptySlot
          ? null
          : TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0.0,
                end: fillFraction.clamp(0.0, 1.0),
              ),
              duration: t.motionBudget,
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: value > 0 ? t.glow(fillColor) : null,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
