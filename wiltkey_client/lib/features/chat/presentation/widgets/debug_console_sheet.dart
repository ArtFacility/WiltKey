import 'package:flutter/material.dart';
import '../../../../core/state.dart';
import '../../../../core/debug_clipboard.dart';
import '../../../../core/theme/wk.dart';

class DebugConsoleSheet extends StatelessWidget {
  final AppState appState;

  const DebugConsoleSheet({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.terminal, color: t.action, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    t.uppercaseLabels ? 'DEBUG ENGINE' : 'Debug console',
                    style: t.screenTitle.copyWith(fontSize: 15),
                  ),
                ],
              ),
              Row(
                children: [
                  // Copy the full log buffer so testers can paste it straight
                  // into a bug report.
                  CopyDebugLogButton(logs: AppState.debugLogs),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: t.danger, size: 20),
                    onPressed: () {
                      AppState.debugLogs.clear();
                      appState.log('[Debug Console] Cleared logs');
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: t.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          Divider(color: t.border),
          Expanded(
            child: ListenableBuilder(
              listenable: AppState.logRevision,
              builder: (context, _) {
                return ListView.builder(
                  itemCount: AppState.debugLogs.length,
                  reverse: true,
                  itemBuilder: (context, index) {
                    final logItem = AppState
                        .debugLogs[AppState.debugLogs.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        logItem,
                        style: t.dataMono.copyWith(
                          color: t.positive,
                          fontSize: 10.5,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static void show(BuildContext context, AppState appState) {
    final t = context.wk;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
      ),
      builder: (context) => DebugConsoleSheet(appState: appState),
    );
  }
}
