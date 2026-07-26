import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/cosmetics/avatar_border_controller.dart';
import '../../../../core/cosmetics/avatar_border_registry.dart';
import '../../../../core/cosmetics/avatar_border_ticker.dart';
import '../../../../core/entitlements/entitlement_service.dart';
import '../../../../core/pixel_art_avatar.dart';
import '../../../../core/theme/wk.dart';
import '../../../shop/presentation/shop_screen.dart';

/// Horizontal strip of equippable avatar borders. Each swatch previews the
/// border over a sample avatar. Premium borders (Play only) show a lock and,
/// when tapped, route to the Shop instead of equipping.
class BorderPicker extends StatelessWidget {
  /// A sample grid to preview borders against (the user's own avatar hex).
  final String sampleHex;

  const BorderPicker({super.key, required this.sampleHex});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return ListenableBuilder(
      listenable: Listenable.merge([
        AvatarBorderController.instance,
        EntitlementService.instance,
      ]),
      builder: (context, _) {
        final currentId = AvatarBorderController.instance.borderId;
        // The picker lists only borders the user could equip here (free always,
        // premium on Play). Premium borders still RENDER on peers via the full
        // registry — they're just not offered in a FOSS user's own picker.
        final borders = WkAvatarBorderRegistry.equippable;
        return SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: borders.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final b = borders[i];
              final selected = b.id == currentId;
              final locked = !WkAvatarBorderRegistry.canEquip(b);
              return GestureDetector(
                onTap: () {
                  if (locked) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const ShopScreen(initialTab: ShopTab.borders),
                      ),
                    );
                  } else {
                    AvatarBorderController.instance.setBorder(b.id);
                  }
                },
                child: Container(
                  width: 84,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: t.surface,
                    border: Border.all(
                      color: selected ? t.action : t.border,
                      width: selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(t.radiusControl),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 48,
                        child: Center(
                          child: b.id == WkAvatarBorderRegistry.noneId
                              ? PixelArtAvatar(hexString: sampleHex, size: 44)
                              : Opacity(
                                  opacity: locked ? 0.5 : 1.0,
                                  child: _preview(b, 48),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              b.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.dataMono.copyWith(
                                color: selected ? t.action : t.textSecondary,
                                fontSize: 9,
                              ),
                            ),
                          ),
                          if (locked) ...[
                            const SizedBox(width: 3),
                            Icon(Icons.lock, size: 9, color: t.textTertiary),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _preview(WkAvatarBorder b, double size) {
    // Reuse the real avatar+border compositor so the preview matches exactly.
    return PixelArtAvatar(hexString: sampleHex, size: size, borderId: b.id);
  }
}

/// Standalone SVG-only border thumbnail (no avatar), for the Shop cards.
class BorderThumbnail extends StatelessWidget {
  final WkAvatarBorder border;
  final double size;
  const BorderThumbnail({super.key, required this.border, this.size = 56});

  @override
  Widget build(BuildContext context) {
    if (border.isAnimated) {
      return SizedBox(
        width: size,
        height: size,
        child: AnimatedAvatarBorder(paint: border.animatedPaint!),
      );
    }
    final asset = border.assetPath;
    if (asset == null) return SizedBox(width: size, height: size);
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => SizedBox(width: size, height: size),
    );
  }
}
