import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/models.dart';
import '../../../../core/state.dart';
import '../../../../core/theme/wk.dart';

/// Approve/Deny dialog for an inbound contact request, shown app-wide (shell)
/// the moment the request arrives — and after unlock for requests that landed
/// while the app was closed. Replaces the in-chat card for group-member
/// requests (user decision 2026-09-14): the activity feed event remains the
/// persistent record, this popup is the moment-of-arrival surface.
Future<void> showContactRequestDialog(
  BuildContext context,
  AppEvent ev,
  AppState appState,
) {
  final t = context.wk;
  final l10n = AppLocalizations.of(context)!;
  final d = ev.dataMap();
  final String name = d['requester_name'] as String? ?? ev.title;

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusCard),
        side: BorderSide(color: t.action.withValues(alpha: 0.4), width: 1.5),
      ),
      title: Text(
        l10n.contactRequestReceived(name),
        style: t.screenTitle.copyWith(fontSize: 16),
      ),
      content: Text(l10n.eventContactRequestBody, style: t.bodySecondary),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            appState.respondToContactRequestEvent(ev, false);
          },
          child: Text(
            l10n.contactRequestDeny,
            style: TextStyle(color: t.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            appState.respondToContactRequestEvent(ev, true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: t.action,
            foregroundColor: t.onAction,
          ),
          child: Text(l10n.contactRequestApprove),
        ),
      ],
    ),
  );
}
