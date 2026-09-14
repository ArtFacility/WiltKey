import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/models.dart';
import '../../../../core/state.dart';
import '../../../../core/theme/wk.dart';

/// Contact-request control card (sent or received). Stored as a plaintext JSON
/// control payload (senderId 'system', never OTP-encrypted) — see
/// state_contacts.dart. Shared by the 1:1 bubble and the group bubble: group
/// chats host these cards for group-member requests, and without this branch
/// the generic system pill renders the raw JSON (caught 2026-09-13).
class ContactRequestCard extends StatelessWidget {
  final ChatMessage message;
  final Contact contact;
  final AppState appState;

  const ContactRequestCard({
    super.key,
    required this.message,
    required this.contact,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;

    Map<String, dynamic> p = {};
    try {
      p = jsonDecode(message.text) as Map<String, dynamic>;
    } catch (_) {}
    final String? reqId = p['req_id'] as String?;
    final String status = p['status'] as String? ?? 'pending';
    final bool received = message.contentType == 'contact_request_received';
    final String peerName = received
        ? (p['requester_name'] as String? ?? contact.name)
        : (p['target_name'] as String? ?? contact.name);
    final bool pending = status == 'pending';

    final String title;
    switch (status) {
      case 'accepted':
        title = l10n.contactRequestApproved;
        break;
      case 'declined':
        title = l10n.contactRequestDeclined;
        break;
      default:
        title = received
            ? l10n.contactRequestReceived(peerName)
            : l10n.contactRequestSent(peerName);
    }
    final Color accent = status == 'declined' ? t.textTertiary : t.action;

    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
          borderRadius: BorderRadius.circular(t.radiusCard),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  received ? Icons.person_add_alt : Icons.person_add,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (pending && received && reqId != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () =>
                        appState.respondToContactRequest(contact, reqId, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.textSecondary,
                      side: BorderSide(color: t.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radiusControl),
                      ),
                    ),
                    child: Text(l10n.contactRequestDeny),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () =>
                        appState.respondToContactRequest(contact, reqId, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.action,
                      foregroundColor: t.onAction,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radiusControl),
                      ),
                    ),
                    child: Text(l10n.contactRequestApprove),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
