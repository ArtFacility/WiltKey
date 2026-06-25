import 'package:flutter/material.dart';
import '../../../../core/theme/wk.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';

class ChargeSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  static const List<String> sliderLabels = [
    '100 KB',
    '1 MB',
    '5 MB',
    '10 MB',
    '20 MB',
  ];

  const ChargeSlider({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final labelSelected = sliderLabels[value.round()];

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
            value: value,
            min: 0.0,
            max: 4.0,
            divisions: 4,
            label: labelSelected,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: sliderLabels
              .map(
                (l) => Text(
                  l,
                  style: t.dataMono.copyWith(
                    color: t.textTertiary,
                    fontSize: 9,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
