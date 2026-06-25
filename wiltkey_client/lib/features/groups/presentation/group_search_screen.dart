import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/state.dart';
import '../../../core/network/pairing_service.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../../core/theme/wiltkey_components.dart';
import '../../proximity/controllers/ble_pairing_manager.dart';
import '../../proximity/presentation/widgets/terminal_log_view.dart';

class GroupSearchScreen extends StatefulWidget {
  const GroupSearchScreen({super.key});

  @override
  State<GroupSearchScreen> createState() => _GroupSearchScreenState();
}

class _GroupSearchScreenState extends State<GroupSearchScreen>
    with TickerProviderStateMixin {
  late BlePairingManager _manager;
  final TextEditingController _relayController = TextEditingController(
    text: AppState.productionRelayUrl,
  );

  String? _pingStatus;
  bool _isPinging = false;

  late AnimationController _connectionController;

  double _flashOpacity = 0.0;
  Timer? _flashTimer;
  bool _hasFlashed = false;

  @override
  void initState() {
    super.initState();
    _manager = BlePairingManager();
    _manager.addListener(_onManagerUpdate);
    _manager.onAlert = _showErrorSnackBar;
    _manager.onHexTick = () {
      if (mounted) setState(() {});
    };

    _connectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    if (_manager.appState.useLocalDevRelay) {
      _relayController.text = _manager.appState.localDevRelayUrl;
    }

    _manager.initializeBle();
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerUpdate);
    _connectionController.dispose();
    _flashTimer?.cancel();
    _relayController.dispose();
    _manager.dispose();
    super.dispose();
  }

  void _onManagerUpdate() {
    if (mounted) {
      setState(() {
        if (_manager.isSuccess &&
            !_hasFlashed &&
            _flashOpacity == 0.0 &&
            _flashTimer == null) {
          _triggerFlash();
        }
      });
    }
  }

  void _triggerFlash() {
    setState(() {
      _flashOpacity = 1.0;
      _hasFlashed = true;
    });

    _flashTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      setState(() {
        _flashOpacity = max(0.0, _flashOpacity - 0.08);
      });
      if (_flashOpacity <= 0.0) {
        timer.cancel();
        _flashTimer = null;
      }
    });
  }

  void _showErrorSnackBar(String message) {
    final t = context.wk;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(backgroundColor: t.danger, content: Text(message)));
  }

  void _runPing() async {
    setState(() {
      _isPinging = true;
      _pingStatus = 'Pinging...';
    });

    final latency = await PairingService.pingRelay(
      _relayController.text.trim(),
    );
    setState(() {
      _isPinging = false;
      if (latency != null) {
        _pingStatus = '${latency}ms';
      } else {
        _pingStatus = 'FAIL';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final closeGroups = _manager.discoveredDevices
        .where((d) => d.isGroup)
        .toList();

    return Stack(
      children: [
        Scaffold(
          backgroundColor: t.bg,
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: t.identity),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              t.uppercaseLabels ? 'SEARCH FOR GROUPS' : 'Find a group',
              style: t.screenTitle.copyWith(fontSize: 16),
            ),
            backgroundColor: t.bg,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(Icons.terminal, color: t.identity, size: 20),
                onPressed: () => TerminalLogView.show(context, _manager),
              ),
            ],
          ),
          body: Container(
            color: t.bg,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_manager.isSyncing && !_manager.isSuccess) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: t.identity.withValues(alpha: 0.05),
                          border: Border.all(
                            color: t.identity.withValues(alpha: 0.2),
                          ),
                          borderRadius: BorderRadius.circular(t.radiusControl),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.wifi_tethering,
                              color: t.identity,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t.uppercaseLabels
                                    ? 'SCANNING FOR GROUP BEACONS'
                                    : 'Scanning for nearby groups',
                                style: t.dataMono.copyWith(
                                  color: t.identity,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      context.wkc.syncVisual(
                        state: SyncVisualState.scanning,
                        blips: _manager.discoveredDevices
                            .where((d) => d.isGroup)
                            .map((d) => d.toSyncBlip())
                            .toList(),
                        log: _manager.terminalLogs,
                      ),
                      const SizedBox(height: 16),
                      _buildNearbyGroupsList(t, closeGroups),
                      const SizedBox(height: 16),
                      _buildDirectSyncForm(t),
                    ] else if (_manager.isSyncing) ...[
                      _buildSyncingProgressCard(t),
                    ] else if (_manager.isSuccess) ...[
                      _buildSuccessCard(t),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_flashOpacity > 0.0)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.white.withValues(alpha: _flashOpacity),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNearbyGroupsList(
    WiltkeyTokens t,
    List<DiscoveredBleDevice> closeGroups,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(
          color: closeGroups.isNotEmpty
              ? t.identity.withValues(alpha: 0.3)
              : t.danger.withValues(alpha: 0.2),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  t.uppercaseLabels
                      ? 'GROUPS WITHIN RANGE (RSSI ≥ $kNearRssi dBm)'
                      : 'Groups within range',
                  style: t.dataMono.copyWith(
                    color: t.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (closeGroups.isNotEmpty)
                Icon(Icons.check_circle_outline, color: t.identity, size: 14)
              else
                Icon(Icons.warning_amber_rounded, color: t.danger, size: 14),
            ],
          ),
          const SizedBox(height: 8),
          if (closeGroups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Ask the group host to open "Invite to group" to start advertising.',
                style: t.bodySecondary,
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: closeGroups.length,
              itemBuilder: (context, index) {
                final dev = closeGroups[index];
                final isSelected = _manager.selectedDevice?.id == dev.id;

                return GestureDetector(
                  onTap: () => _manager.selectDevice(dev),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? t.identity.withValues(alpha: 0.1)
                          : t.bg,
                      border: Border.all(
                        color: isSelected ? t.identity : t.border,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(t.radiusControl),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.hub,
                              color: isSelected ? t.identity : t.textTertiary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              dev.name,
                              style: t.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${dev.rssi} dBm',
                          style: t.dataMono.copyWith(
                            color: isSelected ? t.identity : t.positive,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDirectSyncForm(WiltkeyTokens t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.identity.withValues(alpha: 0.15), width: 1),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Routing server URL', style: t.bodySecondary),
              GestureDetector(
                onTap: _isPinging ? null : _runPing,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: t.bg,
                    border: Border.all(color: t.identity, width: 1),
                    borderRadius: BorderRadius.circular(t.radiusControl),
                  ),
                  child: Text(
                    _isPinging
                        ? 'Pinging…'
                        : _pingStatus != null
                        ? 'Latency: $_pingStatus'
                        : 'Ping relay',
                    style: t.dataMono.copyWith(
                      color: _pingStatus == 'FAIL' ? t.danger : t.identity,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _relayController,
            style: t.dataMono.copyWith(color: t.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              filled: true,
              fillColor: t.bg,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: t.border),
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: t.identity),
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
            ),
            onChanged: (val) {
              _manager.appState.updateDevRelaySettings(
                use: _manager.appState.useLocalDevRelay,
                url: val.trim(),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _manager.selectedDevice == null
                ? null
                : () {
                    _manager.startSyncProcess(_relayController.text.trim());
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: t.identity,
              foregroundColor: Colors.white,
              disabledBackgroundColor: t.surface,
              disabledForegroundColor: t.textTertiary,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
            ),
            child: const Text('Join group'),
          ),
        ],
      ),
    );
  }

  // TODO(animation): barebones group-join sync/success — replace with the garden
  // "growth/bloom" join sequence in the dedicated animation session.
  /// Garden returns its vine→bloom (identity-tinted) for the sync sequence;
  /// cyberpunk returns an empty box (keeps the inline spinner/icon below).
  Widget? _themedSyncVisual(WiltkeyTokens t, SyncVisualState state) {
    final v = context.wkc.syncVisual(
      state: state,
      progress: _manager.syncProgress,
      accent: t.identity,
    );
    return v is SizedBox ? null : v;
  }

  Widget _buildSyncingProgressCard(WiltkeyTokens t) {
    final Widget? themedSync = _themedSyncVisual(t, SyncVisualState.connecting);
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(
          color: t.identity.withValues(alpha: 0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              t.uppercaseLabels
                  ? 'AUTHENTICATING SECURE KEY AGREEMENT'
                  : 'Establishing secure keys',
              style: t.body.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          themedSync ??
              Center(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(t.identity),
                    value: _manager.syncProgress < 0.05
                        ? null
                        : _manager.syncProgress,
                  ),
                ),
              ),
          const SizedBox(height: 20),
          Text(
            _manager.syncStepText,
            textAlign: TextAlign.center,
            style: t.dataMono.copyWith(color: t.textSecondary),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${(_manager.syncProgress * 100).toInt()}% complete',
              style: t.dataMono.copyWith(
                color: t.identity,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: BorderRadius.circular(t.radiusControl),
              border: Border.all(color: t.border),
            ),
            child: Text(
              _manager.randomBytesHex,
              textAlign: TextAlign.left,
              style: t.dataMono.copyWith(
                color: t.identity.withValues(alpha: 0.85),
                fontSize: 9.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard(WiltkeyTokens t) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.identity, width: 1.5),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Column(
        children: [
          _themedSyncVisual(t, SyncVisualState.success) ??
              Icon(Icons.verified, color: t.identity, size: 54),
          const SizedBox(height: 20),
          Text(
            t.uppercaseLabels ? 'JOINED SECURE GROUP' : 'Joined group',
            style: t.screenTitle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Text(
            'Pairwise ECDH keys generated and OTP key derivation link established with the group host. Group metadata is synchronizing…',
            textAlign: TextAlign.center,
            style: t.bodySecondary.copyWith(height: 1.5),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.identity,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
            ),
            child: const Text('Return'),
          ),
        ],
      ),
    );
  }
}
