import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/state.dart';
import '../../../../core/network/pairing_service.dart';
import 'package:wiltkey_client/features/shop/presentation/shop_screen.dart';
import '../../../../core/pad_tiers.dart';
import '../../../../core/storage_space.dart';
import '../../../../core/theme/wk.dart';
import '../../../../core/theme/wiltkey_tokens.dart';
import '../../../../core/theme/wiltkey_components.dart';
import '../controllers/ble_pairing_manager.dart';
import 'widgets/terminal_log_view.dart';
import 'widgets/charge_slider.dart';
import 'widgets/bluetooth_off_banner.dart';
import '../../../../core/entitlements/entitlement_service.dart';

class PairingScreen extends StatefulWidget {
  /// When true, this pairing creates a Time Wilt chat (a lifetime picker
  /// replaces the byte-budget charge slider, and the handshake carries the
  /// Time Wilt mode + expiry). Launched from the Connect hub's Time Wilt card.
  final bool timeWilt;
  const PairingScreen({super.key, this.timeWilt = false});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen>
    with TickerProviderStateMixin {
  late BlePairingManager _manager;

  bool _isEditingName = false;
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _relayController = TextEditingController(
    text: AppState.productionRelayUrl,
  );

  String? _pingStatus;
  bool _isPinging = false;

  late AnimationController _connectionController;

  double _flashOpacity = 0.0;
  Timer? _flashTimer;
  bool _hasFlashed = false;

  // Time Wilt lifetime stops for the slider (label, seconds, Plus-only). The
  // free range runs up to 30 days; Plus extends the SAME slider on to 6 months
  // (all free on FOSS). Kept dense so there's no big 7d→30d jump.
  static const List<(String, int, bool)> _wiltLifetimes = [
    ('1h', 3600, false),
    ('3h', 10800, false),
    ('6h', 21600, false),
    ('12h', 43200, false),
    ('1d', 86400, false),
    ('2d', 172800, false),
    ('3d', 259200, false),
    ('5d', 432000, false),
    ('7d', 604800, false),
    ('14d', 1209600, false),
    ('30d', 2592000, false),
    ('45d', 3888000, true),
    ('60d', 5184000, true),
    ('90d', 7776000, true),
    ('6mo', 15552000, true),
  ];
  int _selectedLifetimeSecs = 604800; // default 7 days

  @override
  void initState() {
    super.initState();
    _manager = BlePairingManager();
    if (widget.timeWilt) {
      _manager.timeWiltMode = true;
      _manager.timeWiltLifetimeSecs = _selectedLifetimeSecs;
    }
    _manager.addListener(_onManagerUpdate);
    _manager.onIncomingRequest = _showIncomingPairDialog;
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

    _deviceNameController.text = _manager.appState.deviceName.isEmpty
        ? _manager.appState.effectiveDeviceName.split(' (')[0]
        : _manager.appState.deviceName;

    _manager.initializeBle();
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerUpdate);
    _connectionController.dispose();
    _flashTimer?.cancel();
    _deviceNameController.dispose();
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

  Future<void> _showIncomingPairDialog({
    required String peerId,
    required String peerPubKey,
    required int bufferBytes,
    required String peerName,
    required String peerShortNick,
    required String peerProfileImage,
    int? wiltExpiresMillis,
    String? wiltFreshSeedHex,
  }) async {
    // Check we can actually fit the pad BEFORE offering Accept. Generating a pad
    // that runs out of disk fails mid-write, after the initiator has already
    // committed — leaving a chat that exists on one side only. Fails open if the
    // platform can't report free space.
    final freeBytes = await WkStorageSpace.usableSpaceBytes();
    final requiredBytes = WkStorageSpace.requiredFor(bufferBytes);
    // Time Wilt writes no pad, so the free-space gate doesn't apply — always
    // enough room. (Its `bufferBytes` is just the default tier, sent unused.)
    final enoughSpace = wiltExpiresMillis != null ||
        freeBytes == null ||
        freeBytes >= requiredBytes;
    // Resolved here so the dialog never has to reason about a nullable probe.
    final freeLabel =
        freeBytes == null ? '?' : AppState.formatBytes(freeBytes);
    if (!mounted) return;

    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusCard),
            side: BorderSide(color: t.positive, width: 1),
          ),
          title: Row(
            children: [
              Icon(Icons.sync_lock, color: t.action, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.uppercaseLabels
                      ? l10n.pairRequestDialogTitle.toUpperCase()
                      : l10n.pairRequestDialogTitle,
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
                wiltExpiresMillis != null
                    ? l10n.timeWiltPairRequestDialogBody(
                        peerName,
                        _wiltLifetimeLabel(l10n, wiltExpiresMillis),
                      )
                    : l10n.pairRequestDialogBody(
                        peerName,
                        AppState.formatBytes(bufferBytes),
                      ),
                style: t.bodySecondary,
              ),
              if (!enoughSpace) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: t.bg,
                    border: Border.all(color: t.danger),
                    borderRadius: BorderRadius.circular(t.radiusControl),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.sd_card_alert_outlined,
                          color: t.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.pairNotEnoughSpace(
                            AppState.formatBytes(requiredBytes),
                            freeLabel,
                          ),
                          style: t.bodySecondary.copyWith(color: t.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _manager.respondToPairRequest(
                  peerId,
                  peerPubKey,
                  bufferBytes,
                  false,
                  peerName,
                  '',
                  '',
                );
              },
              child: Text(
                l10n.pairRequestReject,
                style: TextStyle(color: t.danger),
              ),
            ),
            TextButton(
              // Disabled when the pad can't fit — accepting would fail mid-write
              // and strand the initiator with a one-sided chat.
              onPressed: !enoughSpace
                  ? null
                  : () {
                      Navigator.pop(context);
                       _manager.respondToPairRequest(
                         peerId,
                         peerPubKey,
                         bufferBytes,
                         true,
                         peerName,
                         peerShortNick,
                         peerProfileImage,
                         wiltExpiresMillis: wiltExpiresMillis,
                         wiltFreshSeedHex: wiltFreshSeedHex,
                       );
                    },
              child: Text(
                l10n.pairRequestAccept,
                style: TextStyle(
                  color: enoughSpace ? t.action : t.textTertiary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Initiator-side guard: refuse to start a sync we can't store. The responder
  /// runs the same check before its Accept lights up, so neither side can commit
  /// to a pad that won't fit.
  Future<void> _startSyncChecked() async {
    // Time Wilt writes no pad file, so there's nothing to size-check against
    // free space — go straight to the handshake.
    if (widget.timeWilt) {
      _manager.timeWiltLifetimeSecs = _selectedLifetimeSecs;
      _manager.startSyncProcess(_relayController.text.trim());
      return;
    }
    final padBytes = WkPadTiers.bytesAt(_manager.sliderValue.round());
    final freeBytes = await WkStorageSpace.usableSpaceBytes();
    if (!mounted) return;
    if (freeBytes != null &&
        freeBytes < WkStorageSpace.requiredFor(padBytes)) {
      final l10n = AppLocalizations.of(context)!;
      _showErrorSnackBar(
        l10n.pairNotEnoughSpace(
          AppState.formatBytes(WkStorageSpace.requiredFor(padBytes)),
          AppState.formatBytes(freeBytes),
        ),
      );
      return;
    }
    _manager.startSyncProcess(_relayController.text.trim());
  }

  void _showErrorSnackBar(String message) {
    final t = context.wk;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(backgroundColor: t.danger, content: Text(message)));
  }

  /// Coarse human label for a Time Wilt lifetime, from an absolute expiry.
  String _wiltLifetimeLabel(AppLocalizations l10n, int expiryMillis) {
    final d = Duration(
      milliseconds: expiryMillis - DateTime.now().millisecondsSinceEpoch,
    );
    if (d.inDays >= 1) return l10n.timeWiltLifetimeDays(d.inDays);
    if (d.inHours >= 1) return l10n.timeWiltLifetimeHours(d.inHours);
    if (d.inMinutes >= 1) return l10n.timeWiltLifetimeMinutes(d.inMinutes);
    return l10n.timeWiltLifetimeMoments;
  }

  String _formatLifetimeTick(AppLocalizations l10n, int seconds) {
    if (seconds >= 15552000) {
      return l10n.timeWiltLifetimeMonths(6);
    }
    if (seconds >= 2592000) {
      final months = (seconds / 2592000).round();
      return l10n.timeWiltLifetimeMonths(months);
    }
    if (seconds >= 86400) {
      final days = (seconds / 86400).round();
      return l10n.timeWiltLifetimeDays(days);
    }
    final hours = (seconds / 3600).round();
    return l10n.timeWiltLifetimeHours(hours);
  }

  /// Time Wilt lifetime chooser — a slider (replaces the byte-budget charge
  /// slider) picking how long the chat lives before it wilts to read-only. Free
  /// users slide up to 30 days; Plus extends the same track to 6 months (free on
  /// FOSS). A "Plus" hint below routes to the Shop for locked users.
  Widget _buildLifetimePicker(WiltkeyTokens t) {
    final l10n = AppLocalizations.of(context)!;
    final bool extendedUnlocked =
        EntitlementService.instance.largerPadsUnlocked;
    final int lastFreeIndex =
        _wiltLifetimes.lastIndexWhere((o) => !o.$3);
    final int maxIndex =
        extendedUnlocked ? _wiltLifetimes.length - 1 : lastFreeIndex;
    int currentIndex =
        _wiltLifetimes.indexWhere((o) => o.$2 == _selectedLifetimeSecs);
    if (currentIndex < 0) currentIndex = lastFreeIndex;
    currentIndex = currentIndex.clamp(0, maxIndex);

    final currentTickLabel =
        _formatLifetimeTick(l10n, _wiltLifetimes[currentIndex].$2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t.uppercaseLabels
                  ? l10n.timeWiltLifetimeLabel.toUpperCase()
                  : l10n.timeWiltLifetimeLabel,
              style: t.dataMono.copyWith(
                color: t.textTertiary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              currentTickLabel,
              style: t.dataMono.copyWith(
                color: t.action,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: t.action,
            inactiveTrackColor: t.border,
            thumbColor: t.action,
            overlayColor: t.action.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: currentIndex.toDouble(),
            min: 0,
            max: maxIndex.toDouble(),
            divisions: maxIndex > 0 ? maxIndex : 1,
            label: currentTickLabel,
            onChanged: (v) {
              final idx = v.round().clamp(0, maxIndex);
              setState(() {
                _selectedLifetimeSecs = _wiltLifetimes[idx].$2;
                _manager.timeWiltLifetimeSecs = _selectedLifetimeSecs;
              });
            },
          ),
        ),
        if (!extendedUnlocked)
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ShopScreen(initialTab: ShopTab.plus),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 13, color: t.textTertiary),
                  const SizedBox(width: 6),
                  Text(
                    l10n.timeWiltPlusHint,
                    style: t.bodySecondary.copyWith(color: t.action),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          l10n.timeWiltExplanation,
          style: t.bodySecondary,
        ),
      ],
    );
  }

  void _runPing() async {
    setState(() {
      _isPinging = true;
      _pingStatus = null;
    });

    final latency = await PairingService.pingRelay(
      _relayController.text.trim(),
    );
    setState(() {
      _isPinging = false;
      if (latency != null) {
        _pingStatus = latency.toString();
      } else {
        _pingStatus = 'FAILED';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final closeDevices = _manager.discoveredDevices
        .where((d) => !d.isGroup)
        .toList();

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            iconTheme: IconThemeData(color: t.action),
            title: Text(
              widget.timeWilt
                  ? (t.uppercaseLabels ? 'TIME WILT' : 'Time Wilt')
                  : (t.uppercaseLabels
                        ? l10n.pairTitle.toUpperCase()
                        : l10n.pairTitle),
              style: t.screenTitle.copyWith(fontSize: 18),
            ),
            backgroundColor: t.bg,
            elevation: 0,
            actions: [
              // Manual rescan — replicates the scan restart that leaving and
              // re-entering the screen performs, recovering devices that didn't
              // show up.
              if (!_manager.isSyncing && !_manager.isSuccess)
                IconButton(
                  icon: Icon(Icons.refresh, color: t.action, size: 22),
                  tooltip: l10n.pairRescanTooltip,
                  onPressed: () => _manager.restartScan(),
                ),
              IconButton(
                icon: Icon(Icons.terminal, color: t.action, size: 20),
                onPressed: () => TerminalLogView.show(context, _manager),
              ),
            ],
          ),
          body: _buildProximityBody(t, l10n, closeDevices),
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

  /// The in-person BLE pairing flow — the whole screen body. Pushed as a route
  /// from the Connect hub, so its BLE manager lives only while it's on screen.
  Widget _buildProximityBody(
    WiltkeyTokens t,
    AppLocalizations l10n,
    List<DiscoveredBleDevice> closeDevices,
  ) {
    return Container(
      color: t.bg,
      child: SingleChildScrollView(
        child: Padding(
          // Pad the bottom past the system gesture/nav bar (edge-to-edge) so the
          // last control isn't tucked under it on devices without gesture nav.
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewPadding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_manager.isBluetoothOn) BluetoothOffBanner(manager: _manager),
              if (!_manager.isSyncing && !_manager.isSuccess) ...[
                _buildDeviceNameRow(t),
                const SizedBox(height: 12),
                _buildDiscoverableToggle(t),
                const SizedBox(height: 16),
                context.wkc.syncVisual(
                  state: SyncVisualState.scanning,
                  blips: _manager.discoveredDevices
                      .map((d) => d.toSyncBlip())
                      .toList(),
                  log: _manager.terminalLogs,
                ),
                const SizedBox(height: 16),
                _buildNearbyDevicesList(t, closeDevices),
                const SizedBox(height: 16),
                _buildDirectSyncForm(t),
              ] else if (_manager.isSyncing) ...[
                _buildSyncingProgressCard(t),
                const SizedBox(height: 16),
                _buildHoldWarning(t),
              ] else if (_manager.isSuccess) ...[
                _buildSuccessCard(t),
                const SizedBox(height: 16),
                _buildHoldWarning(t),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Shown while a sync is in progress or just succeeded: leaving the app or
  /// killing it before the peer has also finished can leave only one side with
  /// the contact. Warns the user to keep both devices in the app until both are
  /// done.
  Widget _buildHoldWarning(WiltkeyTokens t) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.budgetWilted.withValues(alpha: 0.08),
        border: Border.all(
          color: t.budgetWilted.withValues(alpha: 0.35),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: t.budgetWilted, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.pairDoNotExitWarning,
              style: t.bodySecondary.copyWith(color: t.budgetWilted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _panel(WiltkeyTokens t, {Color? borderColor}) => BoxDecoration(
    color: t.surface,
    border: Border.all(color: borderColor ?? t.border, width: 1),
    borderRadius: BorderRadius.circular(t.radiusControl),
  );

  Widget _buildDeviceNameRow(WiltkeyTokens t) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panel(t),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.uppercaseLabels
                      ? l10n.pairDeviceNameLabel.toUpperCase()
                      : l10n.pairDeviceNameLabel,
                  style: t.dataMono.copyWith(
                    color: t.textTertiary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                _isEditingName
                    ? TextField(
                        controller: _deviceNameController,
                        style: t.body.copyWith(fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: l10n.pairDeviceNameHint,
                        ),
                        autofocus: true,
                        onSubmitted: (value) {
                          setState(() {
                            _isEditingName = false;
                            _manager.appState.deviceName = value.trim();
                          });
                          _manager.stopAdvertising();
                          _manager.startAdvertising();
                        },
                      )
                    : Text(
                        _manager.appState.effectiveDeviceName,
                        style: t.body.copyWith(fontWeight: FontWeight.bold),
                      ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _isEditingName ? Icons.check : Icons.edit,
              color: t.action,
              size: 18,
            ),
            onPressed: () {
              setState(() {
                if (_isEditingName) {
                  _manager.appState.deviceName = _deviceNameController.text
                      .trim();
                  _manager.stopAdvertising();
                  _manager.startAdvertising();
                }
                _isEditingName = !_isEditingName;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverableToggle(WiltkeyTokens t) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: _panel(t),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pairDiscoverableTitle,
                  style: t.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(l10n.pairDiscoverableSubtitle, style: t.bodySecondary),
              ],
            ),
          ),
          Switch(
            value: _manager.isDiscoverable,
            activeColor: t.action,
            onChanged: (val) => _manager.setDiscoverable(val),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyDevicesList(
    WiltkeyTokens t,
    List<DiscoveredBleDevice> closeDevices,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panel(
        t,
        borderColor: closeDevices.isNotEmpty
            ? t.action.withValues(alpha: 0.3)
            : t.danger.withValues(alpha: 0.2),
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
                      ? l10n.pairNearbyDevicesTitle.toUpperCase()
                      : l10n.pairNearbyDevicesTitle,
                  style: t.dataMono.copyWith(
                    color: t.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (closeDevices.isNotEmpty)
                Icon(Icons.check_circle_outline, color: t.action, size: 14)
              else
                Icon(Icons.warning_amber_rounded, color: t.danger, size: 14),
            ],
          ),
          const SizedBox(height: 8),
          if (closeDevices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                l10n.pairNearbyDevicesInstruction,
                style: t.bodySecondary,
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: closeDevices.length,
              itemBuilder: (context, index) {
                final dev = closeDevices[index];
                final isSelected = _manager.selectedDevice?.id == dev.id;

                return GestureDetector(
                  onTap: () => _manager.selectDevice(dev),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? t.action.withValues(alpha: 0.1)
                          : t.bg,
                      border: Border.all(
                        color: isSelected ? t.action : t.border,
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
                              Icons.smartphone,
                              color: isSelected ? t.action : t.textTertiary,
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
                            color: isSelected ? t.action : t.positive,
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
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panel(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.pairDirectSyncFormRelayLabel, style: t.bodySecondary),
              GestureDetector(
                onTap: _isPinging ? null : _runPing,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: t.bg,
                    border: Border.all(color: t.positive, width: 1),
                    borderRadius: BorderRadius.circular(t.radiusControl),
                  ),
                  child: Text(
                    _isPinging
                        ? l10n.pairPingStatusPinging
                        : _pingStatus != null
                        ? (_pingStatus == 'FAILED'
                              ? l10n.pairPingStatusFailed
                              : l10n.pairPingStatusLatency(_pingStatus!))
                        : l10n.pairPingStatusTest,
                    style: t.dataMono.copyWith(
                      color: _pingStatus == 'FAILED' ? t.danger : t.action,
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
            style: t.dataMono.copyWith(color: t.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: t.bg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: t.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: t.action),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _pingStatus = null;
              });
            },
          ),
          const SizedBox(height: 16),
          if (widget.timeWilt)
            _buildLifetimePicker(t)
          else
            ChargeSlider(
              value: _manager.sliderValue,
              onChanged: (val) => _manager.updateSlider(val),
              onLockedTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ShopScreen(initialTab: ShopTab.plus),
                ),
              ),
            ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _manager.selectedDevice != null
                ? () => _startSyncChecked()
                : null,
            icon: const Icon(Icons.sync_lock, size: 16),
            label: Text(l10n.pairDirectSyncFormSyncButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.action,
              foregroundColor: t.onAction,
              disabledBackgroundColor: t.surface,
              disabledForegroundColor: t.textTertiary,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Garden returns its vine→bloom for the sync sequence; cyberpunk returns an
  /// empty box for these states (and keeps its inline node–line–node graphic).
  /// Returns null when the active theme has no custom sync graphic.
  Widget? _themedSyncVisual(SyncVisualState state) {
    final v = context.wkc.syncVisual(
      state: state,
      progress: _manager.syncProgress,
    );
    return v is SizedBox ? null : v;
  }

  String _localizeSyncStep(String text, AppLocalizations l10n) {
    if (text.startsWith('Establishing secure BLE pairing link') ||
        text.startsWith('Establishing secure Bluetooth link')) {
      return l10n.pairSyncingStep1;
    } else if (text.startsWith('Deriving secure 256-bit seed')) {
      return l10n.pairSyncingStep2;
    } else if (text.startsWith('Exchanging agreed seed')) {
      return l10n.pairSyncingStep3(_manager.agreedSeed);
    } else if (text.startsWith('Deriving high-entropy keystream')) {
      return l10n.pairSyncingStep4;
    } else if (text.startsWith('Verifying pad offset pointer')) {
      return l10n.pairSyncingStep5;
    } else if (text.startsWith('Sync successful') ||
        text.startsWith('Generating keystream file')) {
      return l10n.pairSyncingStep6;
    } else if (text.startsWith('Awaiting peer approval')) {
      return l10n.pairSyncingAwaitingApproval;
    } else if (text.startsWith('Coordinating key derivation')) {
      return l10n.pairSyncingCoordinating;
    }
    return text;
  }

  Widget _buildSyncingProgressCard(WiltkeyTokens t) {
    final l10n = AppLocalizations.of(context)!;
    final String selectedSize =
        ChargeSlider.sliderLabels[_manager.sliderValue.round()];
    final Widget? themedSync = _themedSyncVisual(SyncVisualState.connecting);

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: _panel(t, borderColor: t.action.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          themedSync ??
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _syncNode(t),
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            color: t.surfacePressed,
                          ),
                          AnimatedBuilder(
                            animation: _connectionController,
                            builder: (context, child) {
                              return Align(
                                alignment: Alignment(
                                  -1.0 + (2.0 * _connectionController.value),
                                  0.0,
                                ),
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: t.action,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  _syncNode(t),
                ],
              ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              t.uppercaseLabels
                  ? l10n.pairSyncingConnecting.toUpperCase()
                  : l10n.pairSyncingConnecting,
              style: t.body.copyWith(fontWeight: FontWeight.bold),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.pairSyncingGeneratingKey(selectedSize),
                        style: t.dataMono.copyWith(
                          color: t.textTertiary,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.pairSyncingSeedLabel(_manager.agreedSeed),
                      style: t.dataMono.copyWith(
                        color: t.action,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _manager.randomBytesHex,
                  style: t.dataMono.copyWith(
                    color: t.textSecondary,
                    fontSize: 10,
                    height: 1.4,
                  ),
                  overflow: TextOverflow.clip,
                  softWrap: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: _manager.syncProgress,
            backgroundColor: t.bg,
            color: t.action,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 12),
          Text(
            _manager.isGeneratingPad
                ? l10n.pairSyncingGenerating(
                    AppState.formatBytes(_manager.padWrittenBytes),
                    AppState.formatBytes(_manager.padTotalBytes),
                  )
                : _localizeSyncStep(_manager.syncStepText, l10n),
            textAlign: TextAlign.center,
            style: t.dataMono.copyWith(color: t.textSecondary),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              l10n.pairSyncingPercentComplete(
                (_manager.syncProgress * 100).toInt(),
              ),
              style: t.dataMono.copyWith(
                color: t.action,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_manager.isGeneratingPad) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: t.warning, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.pairKeepAppOpen,
                    style: t.bodySecondary.copyWith(color: t.warning),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => _manager.abortHandshake(),
                icon: Icon(Icons.close, size: 16, color: t.textSecondary),
                label: Text(
                  l10n.commonCancel,
                  style: TextStyle(color: t.textSecondary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _syncNode(WiltkeyTokens t) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: t.action.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(t.radiusControl),
      border: Border.all(color: t.action.withValues(alpha: 0.3)),
    ),
    child: Icon(Icons.smartphone, color: t.action, size: 28),
  );

  Widget _buildSuccessCard(WiltkeyTokens t) {
    final l10n = AppLocalizations.of(context)!;
    final String title = _manager.selectedDevice?.name ?? 'Secure Peer';
    final String label =
        ChargeSlider.sliderLabels[_manager.sliderValue.round()];
    final Widget? themedBloom = _themedSyncVisual(SyncVisualState.success);

    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(24),
      decoration: _panel(t, borderColor: t.action),
      child: Column(
        children: [
          themedBloom ??
              Icon(Icons.check_circle_outline, color: t.action, size: 54),
          const SizedBox(height: 20),
          Text(
            t.uppercaseLabels
                ? l10n.pairSuccessConnectionSecured.toUpperCase()
                : l10n.pairSuccessConnectionSecured,
            style: t.screenTitle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          Text(
            _manager.incomingGroupMetadata != null
                ? l10n.pairSuccessGroupBody(
                    _manager.incomingGroupMetadata!['groupName'] as String,
                  )
                : l10n.pairSuccessOneOnOneBody(title, label),
            textAlign: TextAlign.center,
            style: t.bodySecondary.copyWith(height: 1.5),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              _manager.resetState();
              // Pop with success so the Connect hub (still a shell descendant,
              // unlike this pushed route) can jump to the Chats tab.
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: t.action,
              foregroundColor: t.onAction,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
            ),
            child: Text(l10n.pairSuccessReturnButton),
          ),
        ],
      ),
    );
  }
}
