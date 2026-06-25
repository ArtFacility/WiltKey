import 'package:flutter/material.dart';
import '../../../../core/state.dart';
import '../../../../core/models.dart';
import '../../../../core/theme/wk.dart';

class DiagnosticsDialog extends StatelessWidget {
  final Contact contact;
  final String myUserId;

  const DiagnosticsDialog({
    super.key,
    required this.contact,
    required this.myUserId,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final bool isInitiator = myUserId.compareTo(contact.keyHash) < 0;

    final String remainingMe = AppState.formatBytes(
      contact.remainingBufferBytes,
    );
    final int theirBytes = contact.getTheirRemainingBytes(myUserId);
    final String remainingPeer = AppState.formatBytes(theirBytes);
    final String totalBytes = AppState.formatBytes(contact.maxBufferBytes);

    final line = t.dataMono.copyWith(color: t.textSecondary, fontSize: 9.5);
    final label = t.dataMono.copyWith(
      color: t.textPrimary,
      fontSize: 9,
      fontWeight: FontWeight.bold,
    );

    return AlertDialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusCard),
        side: BorderSide(color: t.positive, width: 1.5),
      ),
      title: Row(
        children: [
          Icon(Icons.analytics_outlined, color: t.action, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t.uppercaseLabels
                  ? 'SECURE LANE DIAGNOSTICS'
                  : 'Secure lane diagnostics',
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
            'Contact: ${contact.name}',
            style: label.copyWith(color: t.action),
          ),
          const SizedBox(height: 12),
          Text('My sending channel (outbound):', style: label),
          const SizedBox(height: 4),
          Text(
            '  · Keystream range: ${contact.outgoingOffset} / ${contact.outgoingMaxOffset} bytes',
            style: line,
          ),
          Text('  · Remaining budget: $remainingMe', style: line),
          const SizedBox(height: 12),
          Text('Peer channel (inbound):', style: label),
          const SizedBox(height: 4),
          Text(
            '  · Keystream range: ${contact.incomingOffset} / ${contact.incomingMaxOffset} bytes',
            style: line,
          ),
          Text('  · Remaining budget: $remainingPeer', style: line),
          const SizedBox(height: 12),
          Text('Overall specifications:', style: label),
          const SizedBox(height: 4),
          Text(
            '  · Partition role: ${isInitiator ? "Initiator (Alice)" : "Receiver (Bob)"}',
            style: line,
          ),
          Text('  · Total enclave storage: $totalBytes', style: line),
          Text(
            '  · Status: ${contact.isWilted ? "Wilted" : "Connected / active"}',
            style: line.copyWith(
              color: contact.isWilted ? t.danger : t.positive,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: t.surface,
            foregroundColor: t.action,
            side: BorderSide(color: t.positive, width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
          ),
          child: const Text('Dismiss'),
        ),
      ],
    );
  }

  static void show(BuildContext context, Contact contact, String myUserId) {
    showDialog(
      context: context,
      builder: (context) =>
          DiagnosticsDialog(contact: contact, myUserId: myUserId),
    );
  }
}
