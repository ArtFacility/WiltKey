import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../models.dart';
import '../wk.dart';

/// Renders a verification badge indicating client authenticity:
/// - 🛡️✨ Golden Shield: Official Google Play Store build + Active Plus Supporter
/// - 🛡️ Primary Shield: Official Google Play Store build
/// - 🔧 Wrench: Open Source / Community / Tinkerer build
class ClientIntegrityBadge extends StatelessWidget {
  final ClientBadgeType badgeType;
  final double size;
  final bool interactive;
  final bool showLabel;

  const ClientIntegrityBadge({
    super.key,
    required this.badgeType,
    this.size = 14.0,
    this.interactive = true,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context);

    final Widget icon;
    final String label;

    switch (badgeType) {
      case ClientBadgeType.playPlus:
        icon = Icon(
          Icons.shield_rounded,
          size: size,
          color: const Color(0xFFFFD700), // Gold
        );
        label = l10n?.badgePlayPlus ?? 'Play Store · Plus';
        break;
      case ClientBadgeType.playOfficial:
        icon = Icon(
          Icons.shield_rounded,
          size: size,
          color: t.action,
        );
        label = l10n?.badgePlayVerified ?? 'Play Store';
        break;
      case ClientBadgeType.tinkerer:
        icon = Icon(
          Icons.build_rounded,
          size: size * 0.9,
          color: t.textTertiary,
        );
        label = l10n?.badgeFoss ?? 'Open Source';
        break;
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        icon,
        if (showLabel) ...[
          const SizedBox(width: 4),
          Text(
            label,
            style: t.dataMono.copyWith(
              fontSize: size * 0.85,
              color: badgeType == ClientBadgeType.playPlus
                  ? const Color(0xFFFFD700)
                  : badgeType == ClientBadgeType.playOfficial
                      ? t.action
                      : t.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );

    if (!interactive) return content;

    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showAttestationSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: content,
        ),
      ),
    );
  }

  void _showAttestationSheet(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;

    final IconData sheetIcon;
    final Color sheetIconColor;
    final String sheetTitle;
    final String sheetSubtitle;
    final String sheetBody;

    switch (badgeType) {
      case ClientBadgeType.playPlus:
        sheetIcon = Icons.shield_rounded;
        sheetIconColor = const Color(0xFFFFD700);
        sheetTitle = l10n.badgePlayPlus;
        sheetSubtitle = l10n.badgePlayPlusSubtitle;
        sheetBody = l10n.badgePlayPlusExplainer;
        break;
      case ClientBadgeType.playOfficial:
        sheetIcon = Icons.shield_rounded;
        sheetIconColor = t.action;
        sheetTitle = l10n.badgePlayVerified;
        sheetSubtitle = l10n.badgePlayVerifiedSubtitle;
        sheetBody = l10n.badgePlayVerifiedExplainer;
        break;
      case ClientBadgeType.tinkerer:
        sheetIcon = Icons.build_rounded;
        sheetIconColor = t.textSecondary;
        sheetTitle = l10n.badgeFoss;
        sheetSubtitle = l10n.badgeFossSubtitle;
        sheetBody = l10n.badgeFossExplainer;
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
        side: BorderSide(color: t.border),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sheetIconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(sheetIcon, color: sheetIconColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sheetTitle,
                          style: t.body.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sheetSubtitle,
                          style: t.dataMono.copyWith(
                            color: t.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: t.border, height: 1),
              const SizedBox(height: 14),
              Text(
                sheetBody,
                style: t.bodySecondary.copyWith(height: 1.45, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.action,
                    foregroundColor: t.onAction,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(t.radiusControl),
                    ),
                  ),
                  child: Text(l10n.commonClose),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
