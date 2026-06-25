import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/theme/wk.dart';

class NukeConfirmDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const NukeConfirmDialog({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusCard),
        side: BorderSide(color: t.danger, width: 1.5),
      ),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: t.danger, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t.uppercaseLabels
                  ? l10n.chatDetailsDeleteConfirmTitle.toUpperCase()
                  : l10n.chatDetailsDeleteConfirmTitle,
              style: t.screenTitle.copyWith(color: t.danger, fontSize: 16),
            ),
          ),
        ],
      ),
      content: Text(
        l10n.chatDetailsDeleteConfirmBody,
        style: t.bodySecondary.copyWith(height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.commonCancel,
            style: TextStyle(color: t.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: t.danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
          ),
          child: Text(l10n.chatDetailsDeleteConfirmButton),
        ),
      ],
    );
  }

  static void show(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => NukeConfirmDialog(onConfirm: onConfirm),
    );
  }
}
