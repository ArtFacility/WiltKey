import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/wk.dart';

/// Copies [logs] to the clipboard and shows a confirmation snackbar. Shared by
/// every debug console (chat, dashboard, settings, and the pairing terminal) so
/// the "copy debug" affordance looks and behaves identically everywhere — handy
/// for testers pasting logs straight into a bug report.
Future<void> copyDebugLogs(BuildContext context, List<String> logs) async {
  final t = context.wk;
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: logs.join('\n')));
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: t.surface,
      content: Text(
        'Debug log copied (${logs.length} lines)',
        style: t.bodySecondary.copyWith(color: t.action),
      ),
    ),
  );
}

/// A standard copy-log icon button used across the debug consoles.
class CopyDebugLogButton extends StatelessWidget {
  final List<String> logs;
  const CopyDebugLogButton({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return IconButton(
      icon: Icon(Icons.copy_all_outlined, color: t.action, size: 20),
      tooltip: 'Copy debug log',
      onPressed: () => copyDebugLogs(context, logs),
    );
  }
}
