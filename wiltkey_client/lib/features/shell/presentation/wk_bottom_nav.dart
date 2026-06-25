import 'package:flutter/material.dart';
import '../../../core/theme/wk.dart';

class WkNavItem {
  final IconData icon;
  final String label;
  const WkNavItem(this.icon, this.label);
}

/// Token-driven bottom navigation bar. Same structure in every theme; the active
/// item uses `tokens.action`, the bar sits on a `tokens.border` top hairline.
class WkBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<WkNavItem> items;

  const WkBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(
          top: BorderSide(color: t.border, width: t.borderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final selected = i == currentIndex;
              final color = selected ? t.action : t.textTertiary;
              final item = items[i];
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(t.radiusControl),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, size: 22, color: color),
                        const SizedBox(height: 4),
                        Text(
                          t.uppercaseLabels
                              ? item.label.toUpperCase()
                              : item.label,
                          style: t.sectionLabel.copyWith(
                            color: color,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
