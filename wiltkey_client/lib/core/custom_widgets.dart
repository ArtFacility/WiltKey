import 'package:flutter/material.dart';
import 'theme/wk.dart';

class PrivateNodeBadge extends StatelessWidget {
  const PrivateNodeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: t.warning.withValues(alpha: 0.1),
        border: Border.all(color: t.warning.withValues(alpha: 0.3), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hub_outlined, size: 11, color: t.warning),
          const SizedBox(width: 4),
          Text(
            t.uppercaseLabels ? 'PRIVATE NODE' : 'Private node',
            style: t.badgeLabel.copyWith(color: t.warning),
          ),
        ],
      ),
    );
  }
}
