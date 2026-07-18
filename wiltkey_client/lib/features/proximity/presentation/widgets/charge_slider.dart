import 'package:flutter/material.dart';
import '../../../../core/pad_tiers.dart';
import '../../../../core/theme/wk.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';

/// Pad-size picker shown to the pairing **initiator**.
///
/// The track spans only the tiers this user may actually pick
/// ([WkPadTiers.selectableMaxIndex]) — free users top out at 20 MB and get a
/// tappable hint offering the larger tiers, rather than a slider that silently
/// refuses to move. Sizes live in [WkPadTiers]; only the initiator's choice
/// matters (the responder honours whatever byte count arrives).
class ChargeSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  /// Tapped when a free user touches the "larger pads" upsell (routes to the Shop).
  final VoidCallback? onLockedTap;

  /// Back-compat alias — labels now live in [WkPadTiers.labels].
  static List<String> get sliderLabels => WkPadTiers.labels;

  const ChargeSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final maxIndex = WkPadTiers.selectableMaxIndex;
    final labelSelected = WkPadTiers.labelAt(value.round());
    final showUpsell = !WkPadTiers.largerUnlocked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.pairChatSize, style: t.bodySecondary),
            Text(
              labelSelected,
              style: t.dataMono.copyWith(
                color: t.action,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: t.action,
            inactiveTrackColor: t.budgetEmpty,
            thumbColor: t.action,
            overlayColor: t.action.withValues(alpha: 0.2),
            valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
            valueIndicatorColor: t.surface,
            valueIndicatorTextStyle: t.dataMono.copyWith(color: t.action),
          ),
          child: Slider(
            // Clamped so a stale/higher value (e.g. an entitlement that lapsed)
            // can never sit outside the track.
            value: value.clamp(0, maxIndex).toDouble(),
            min: 0.0,
            max: maxIndex.toDouble(),
            divisions: maxIndex,
            label: labelSelected,
            onChanged: onChanged,
          ),
        ),
        // Only the endpoints — 13 tiers can't all fit as a label row.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              WkPadTiers.labelAt(0),
              style: t.dataMono.copyWith(color: t.textTertiary, fontSize: 9),
            ),
            Text(
              WkPadTiers.labelAt(maxIndex),
              style: t.dataMono.copyWith(color: t.textTertiary, fontSize: 9),
            ),
          ],
        ),
        if (showUpsell) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: onLockedTap,
            borderRadius: BorderRadius.circular(t.radiusControl),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.lock_open, size: 13, color: t.action),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.pairLargerPadsUpsell(
                        WkPadTiers.labelAt(WkPadTiers.maxIndex),
                      ),
                      style: t.bodySecondary.copyWith(color: t.action),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 14, color: t.action),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
