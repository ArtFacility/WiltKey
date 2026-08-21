import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/theme/wk.dart';
import 'link_warning_easter_eggs.dart';

/// Shows a security warning dialog before the user leaves WiltKey to open an
/// external URL in their browser.
///
/// Discloses the destination URL, warns about external metadata/IP leakage,
/// and allows copying the link or opening it in an external application.
Future<void> showLinkWarningDialog(BuildContext context, Uri uri) async {
  final t = context.wk;
  final l10n = AppLocalizations.of(context)!;
  final String urlString = uri.toString();
  final String langCode = Localizations.localeOf(context).languageCode;
  final String? easterEgg = getLinkEasterEgg(uri, langCode);
  final String warningBody = easterEgg ?? l10n.linkWarningBody;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.border, width: t.borderWidth),
        ),
        title: Row(
          children: [
            Icon(
              easterEgg != null ? Icons.lightbulb_outline : Icons.shield_outlined,
              color: easterEgg != null ? t.action : t.warning,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.uppercaseLabels
                    ? l10n.linkWarningTitle.toUpperCase()
                    : l10n.linkWarningTitle,
                style: t.screenTitle.copyWith(fontSize: 15),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              warningBody,
              style: t.bodySecondary.copyWith(
                height: 1.4,
                fontSize: 13,
                color: easterEgg != null ? t.textPrimary : t.textSecondary,
                fontWeight: easterEgg != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: t.bg,
                border: Border.all(color: t.border, width: 1),
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      urlString,
                      style: t.dataMono.copyWith(
                        color: t.action,
                        fontSize: 12,
                      ),
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.copy, size: 18, color: t.textSecondary),
                    tooltip: l10n.linkWarningCopy,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: urlString));
                      HapticFeedback.selectionClick();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.linkWarningCopied),
                          backgroundColor: t.action,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              l10n.commonCancel,
              style: t.body.copyWith(color: t.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(
              t.uppercaseLabels
                  ? l10n.linkWarningOpen.toUpperCase()
                  : l10n.linkWarningOpen,
              style: t.badgeLabel.copyWith(
                color: t.onAction,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.action,
              foregroundColor: t.onAction,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
          ),
        ],
      );
    },
  );
}
