import 'package:flutter/material.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/state.dart';
import 'package:wiltkey_client/core/theme/wk.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';

/// The "Add contact" / "Cancel" confirm popup. Returns true when confirmed.
Future<bool> showAddContactDialog(
  BuildContext context, {
  required String name,
}) async {
  final t = context.wk;
  final l10n = AppLocalizations.of(context)!;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusCard),
        side: BorderSide(color: t.border, width: t.borderWidth),
      ),
      title: Text(
        l10n.contactAddTitle,
        style: t.screenTitle.copyWith(fontSize: 16),
      ),
      content: Text(
        l10n.contactAddBody(name),
        style: t.bodySecondary.copyWith(height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(
            l10n.commonCancel,
            style: TextStyle(color: t.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.contactAddConfirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Full "add contact" flow from a chat UI: skips straight to a toast when the
/// peer is already a contact, otherwise shows the Add/Cancel popup, sends the
/// targeted request over the AES meta channel, and reports the outcome.
///
/// Pass either [contact] (an existing 1:1 chat peer — the sent card is inserted
/// into that chat) or [keyHash]+[name] (e.g. a group member) with an optional
/// [chatContact] for the card placement when a direct chat exists.
Future<void> showAddContactFlow(
  BuildContext context, {
  required AppState appState,
  Contact? contact,
  String? keyHash,
  String? name,
  Contact? chatContact,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final String targetKey = contact?.keyHash ?? keyHash!;
  final String targetName = contact?.name ?? name!;

  if (appState.socialContacts.any((c) => c.keyHash == targetKey)) {
    _toast(context, l10n.contactAddAlready);
    return;
  }

  final ok = await showAddContactDialog(context, name: targetName);
  if (!ok || !context.mounted) return;

  final String? err = contact != null
      ? await appState.sendContactRequest(contact)
      : await appState.sendContactRequestToKey(
          keyHash: targetKey,
          name: targetName,
          chatContact: chatContact,
        );
  if (err != null) {
    if (!context.mounted) return;
    _toast(context, err);
    return;
  }
  if (!context.mounted) return;
  _toast(context, l10n.contactAddSent);
}
void _toast(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: context.wk.surface,
    ),
  );
}
