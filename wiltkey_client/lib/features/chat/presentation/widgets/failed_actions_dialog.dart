import 'package:flutter/material.dart';
import '../../../../core/state.dart';
import '../../../../core/models.dart';
import '../../../../core/theme/wk.dart';

class FailedActionsDialog extends StatelessWidget {
  final Contact contact;
  final ChatMessage message;
  final AppState appState;

  const FailedActionsDialog({
    super.key,
    required this.contact,
    required this.message,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return AlertDialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusCard),
        side: BorderSide(color: t.warning, width: 1.5),
      ),
      title: Row(
        children: [
          Icon(Icons.error_outline, color: t.warning, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t.uppercaseLabels ? 'MESSAGE FAILED' : 'Message failed',
              style: t.screenTitle.copyWith(fontSize: 16),
            ),
          ),
        ],
      ),
      content: Text(
        'This message failed to send because your device was offline.\n\nChoose an action below.',
        style: t.bodySecondary.copyWith(height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await appState.clearFailedMessage(contact, message);
          },
          child: Text('Clear & refund', style: TextStyle(color: t.danger)),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            final sent = await appState.retrySendMessage(contact, message);
            if (!sent && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: t.surface,
                  content: Text(
                    'Connection still offline. Cannot retry.',
                    style: t.bodySecondary.copyWith(color: t.danger),
                  ),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: t.action,
            foregroundColor: t.onAction,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
          ),
          child: const Text('Retry send'),
        ),
      ],
    );
  }

  static void show(
    BuildContext context,
    Contact contact,
    ChatMessage message,
    AppState appState,
  ) {
    showDialog(
      context: context,
      builder: (context) => FailedActionsDialog(
        contact: contact,
        message: message,
        appState: appState,
      ),
    );
  }
}
