import 'package:flutter/material.dart';
import '../../controllers/ble_pairing_manager.dart';
import '../../../../core/theme/wk.dart';

class TerminalLogView extends StatelessWidget {
  final BlePairingManager manager;

  const TerminalLogView({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t.uppercaseLabels ? 'DEBUG TERMINAL' : 'Activity log',
                    style: t.screenTitle.copyWith(fontSize: 15),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: t.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.bg,
                    border: Border.all(color: t.border),
                    borderRadius: BorderRadius.circular(t.radiusControl),
                  ),
                  child: ListView.builder(
                    itemCount: manager.terminalLogs.length,
                    itemBuilder: (context, index) {
                      return Text(
                        manager.terminalLogs[index],
                        style: t.dataMono.copyWith(
                          color: t.positive,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static void show(BuildContext context, BlePairingManager manager) {
    final t = context.wk;
    showModalBottomSheet(
      context: context,
      backgroundColor: t.bg,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
        side: BorderSide(color: t.positive, width: 1),
      ),
      builder: (context) => TerminalLogView(manager: manager),
    );
  }
}
