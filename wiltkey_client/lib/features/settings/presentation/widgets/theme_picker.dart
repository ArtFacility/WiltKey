import 'package:flutter/material.dart';
import '../../../../core/entitlements/entitlement_service.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_registry.dart';
import '../../../../core/theme/wk.dart';
import '../../../../core/theme/wiltkey_components.dart';
import '../../../shop/presentation/shop_screen.dart';

/// The real "Appearance" theme picker: one card per registered theme, each
/// rendered with THAT theme's own tokens (a live preview), driven entirely by
/// [WiltkeyThemeRegistry] — a new theme appears here automatically.
///
/// Premium themes (Play build only) show a lock until they're owned; tapping a
/// locked card routes to the Shop rather than switching the theme.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController(),
      builder: (context, _) {
        return ListenableBuilder(
          listenable: EntitlementService.instance,
          builder: (context, _) {
            final currentId = ThemeController().themeId;
            return Column(
              children: WiltkeyThemeRegistry.all.map((d) {
                final locked = d.premium &&
                    !EntitlementService.instance.premiumThemeUnlocked(d.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ThemeCard(
                    descriptor: d,
                    selected: d.id == currentId,
                    locked: locked,
                    onTap: () {
                      if (locked) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ShopScreen(),
                          ),
                        );
                      } else {
                        ThemeController().setTheme(d.id);
                      }
                    },
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final WiltkeyThemeDescriptor descriptor;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.descriptor,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Render the card body inside the candidate theme so context.wk / wkc
    // resolve to ITS tokens — a true live preview.
    return Theme(
      data: descriptor.build(),
      child: Builder(
        builder: (context) {
          final t = context.wk;
          return GestureDetector(
            onTap: onTap,
            child: Opacity(
              // Locked premium themes still render their true preview (rendering
              // is never gated) — just muted to read as "not yours yet".
              opacity: locked ? 0.55 : 1.0,
              child: AnimatedContainer(
              duration: t.motionShort,
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.bg,
                borderRadius: BorderRadius.circular(t.radiusCard),
                border: Border.all(
                  color: selected ? t.action : t.border,
                  width: selected ? 2 : t.borderWidth,
                ),
              ),
              child: Row(
                children: [
                  // Live budget glyph in this theme.
                  context.wkc.budgetIndicator(
                    ourFraction: 0.75,
                    theirFraction: 0.5,
                    isWilted: false,
                    variant: BudgetIndicatorVariant.listRow,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                descriptor.localizedName(context),
                                style: t.body
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (locked) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.lock, size: 12, color: t.textSecondary),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          descriptor.localizedTagline(context),
                          style: t.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                  if (locked)
                    Icon(Icons.shopping_bag_outlined, color: t.action, size: 20)
                  else if (selected)
                    Icon(Icons.check_circle, color: t.action, size: 20)
                  else
                    Icon(
                      Icons.circle_outlined,
                      color: t.textTertiary,
                      size: 20,
                    ),
                ],
              ),
              ),
            ),
          );
        },
      ),
    );
  }
}
