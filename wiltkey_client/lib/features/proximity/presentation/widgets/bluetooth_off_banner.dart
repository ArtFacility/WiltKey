import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/theme/wk.dart';
import '../../controllers/ble_pairing_manager.dart';

/// Warning banner shown on the pair screens when the Bluetooth adapter is off.
/// Pairing relies on BLE scanning + advertising, which silently never start when
/// the radio is off — leaving the screen looking frozen. This makes the cause
/// explicit and offers a one-tap "turn on" (Android shows the system prompt).
///
/// Reactive: the [BlePairingManager] tracks the live adapter state and the
/// screens rebuild when it flips, so the banner appears/disappears on its own
/// and discovery auto-resumes once Bluetooth comes back on.
class BluetoothOffBanner extends StatelessWidget {
  final BlePairingManager manager;
  const BluetoothOffBanner({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.danger.withValues(alpha: 0.08),
        border: Border.all(color: t.danger.withValues(alpha: 0.4), width: 1),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bluetooth_disabled, color: t.danger, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.pairBluetoothOffWarning,
                  style: t.bodySecondary.copyWith(color: t.danger, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => manager.requestBluetoothOn(),
              icon: const Icon(Icons.bluetooth, size: 16),
              label: Text(l10n.pairBluetoothTurnOnButton),
              style: OutlinedButton.styleFrom(
                foregroundColor: t.danger,
                side: BorderSide(color: t.danger, width: 1),
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
