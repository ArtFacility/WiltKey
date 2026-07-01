import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../../core/state.dart';
import '../../../core/models.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../../core/theme/wiltkey_components.dart';
import '../../proximity/controllers/ble_pairing_manager.dart';
import '../../proximity/presentation/widgets/terminal_log_view.dart';
import '../../proximity/presentation/widgets/bluetooth_off_banner.dart';

class GroupInviteScreen extends StatefulWidget {
  final Contact group;
  const GroupInviteScreen({super.key, required this.group});

  @override
  State<GroupInviteScreen> createState() => _GroupInviteScreenState();
}

class _GroupInviteScreenState extends State<GroupInviteScreen> {
  late BlePairingManager _manager;

  double _flashOpacity = 0.0;
  Timer? _flashTimer;
  bool _hasFlashed = false;

  @override
  void initState() {
    super.initState();
    _manager = BlePairingManager();
    _manager.groupToInvite = widget.group;
    _manager.addListener(_onManagerUpdate);
    _manager.onIncomingRequest = _showIncomingJoinDialog;
    _manager.onAlert = _showErrorSnackBar;

    _manager.initializeBle();
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerUpdate);
    _flashTimer?.cancel();
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

  void _showIncomingJoinDialog({
    required String peerId,
    required String peerPubKey,
    required int bufferBytes,
    required String peerName,
    required String peerShortNick,
    required String peerProfileImage,
  }) {
    final t = context.wk;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusCard),
            side: BorderSide(color: t.identity, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(Icons.group_add, color: t.identity, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.uppercaseLabels
                      ? 'GROUP INVITE REQUEST'
                      : 'Group invite request',
                  style: t.screenTitle.copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
          content: Text(
            'Add $peerName to group "${widget.group.name}"?\n\nKey buffer: ${AppState.formatBytes(bufferBytes)}.',
            style: t.bodySecondary.copyWith(height: 1.5),
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
              child: Text('Reject', style: TextStyle(color: t.danger)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _manager.respondToPairRequest(
                  peerId,
                  peerPubKey,
                  bufferBytes,
                  true,
                  peerName,
                  peerShortNick,
                  peerProfileImage,
                );
              },
              child: Text('Accept & add', style: TextStyle(color: t.action)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    final t = context.wk;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(backgroundColor: t.danger, content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return Stack(
      children: [
        Scaffold(
          backgroundColor: t.bg,
          appBar: AppBar(
            backgroundColor: t.bg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: t.action),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              t.uppercaseLabels ? 'INVITE TO GROUP' : 'Invite to group',
              style: t.screenTitle.copyWith(fontSize: 16),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.terminal, color: t.action, size: 20),
                onPressed: () => TerminalLogView.show(context, _manager),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_manager.isBluetoothOn)
                    BluetoothOffBanner(manager: _manager),
                  if (!_manager.isSyncing && !_manager.isSuccess) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.surface,
                        border: Border.all(
                          color: t.identity.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(t.radiusControl),
                      ),
                      child: Row(
                        children: [
                          PixelArtAvatar(
                            hexString:
                                widget.group.groupIconHex ??
                                PixelArtAvatar.generateIdenticon(
                                  widget.group.keyHash,
                                ),
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.group.name,
                                  style: t.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Host: ${widget.group.hostName}',
                                  style: t.bodySecondary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: t.action.withValues(alpha: 0.05),
                        border: Border.all(
                          color: t.action.withValues(alpha: 0.2),
                        ),
                        borderRadius: BorderRadius.circular(t.radiusControl),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_tethering, color: t.action, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.uppercaseLabels
                                  ? 'ADVERTISING PRESENCE OVER BLE'
                                  : 'Advertising over BLE',
                              style: t.dataMono.copyWith(
                                color: t.action,
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
                      blips: const [],
                      log: _manager.terminalLogs,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Ask the member to open the Pair tab on their device and select your device name to join this group.',
                      textAlign: TextAlign.center,
                      style: t.bodySecondary.copyWith(height: 1.5),
                    ),
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

  // TODO(animation): barebones invite sync/success — replace with the garden
  // "growth/bloom" join sequence in the dedicated animation session.
  /// Garden returns its vine→bloom (identity-tinted) for the sync sequence;
  /// cyberpunk returns an empty box (keeps the plain progress bar / icon).
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
                  ? 'PEER-TO-PEER HANDSHAKE ACTIVE'
                  : 'Handshake in progress',
              style: t.body.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          if (themedSync != null) ...[themedSync, const SizedBox(height: 16)],
          LinearProgressIndicator(
            value: _manager.syncProgress,
            backgroundColor: t.bg,
            color: t.identity,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 12),
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
        border: Border.all(color: t.action, width: 1.5),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Column(
        children: [
          _themedSyncVisual(t, SyncVisualState.success) ??
              Icon(Icons.check_circle_outline, color: t.action, size: 54),
          const SizedBox(height: 20),
          Text(
            t.uppercaseLabels ? 'MEMBER ADDED SECURELY' : 'Member added',
            style: t.screenTitle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Text(
            'Handshake completed successfully. Generated secure pairwise key file and added member to group "${widget.group.name}".',
            textAlign: TextAlign.center,
            style: t.bodySecondary.copyWith(height: 1.5),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.action,
              foregroundColor: t.onAction,
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
