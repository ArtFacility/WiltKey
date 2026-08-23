import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/network/remote_pairing_controller.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../chat/presentation/chat_screen.dart';

/// Full-screen QR code connect flow (7-day Time Wilt default for 1:1 chats).
class QrPairingScreen extends StatefulWidget {
  const QrPairingScreen({super.key});

  @override
  State<QrPairingScreen> createState() => _QrPairingScreenState();
}

class _QrPairingScreenState extends State<QrPairingScreen>
    with SingleTickerProviderStateMixin {
  late final RemotePairingController _controller;
  late final TabController _tabController;
  final MobileScannerController _scannerController = MobileScannerController();

  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _hashController = TextEditingController();
  bool _manualEntry = false;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _controller = RemotePairingController()..addListener(_onStateChange);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (_tabController.index == 1) {
      // Switched to My QR Code tab -> pause scanner to save camera & start hosting
      _scannerController.stop();
      if (_controller.phase == RemotePairPhase.idle) {
        _controller.startHosting();
      }
    } else {
      // Switched to Scan QR tab -> resume camera scanner
      _scanned = false;
      _scannerController.start();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChange);
    _tabController.dispose();
    _scannerController.dispose();
    _pinController.dispose();
    _hashController.dispose();
    _controller.removeListener(_onStateChange);
    _controller.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted) return;
    setState(() {});

    if (_controller.phase == RemotePairPhase.success &&
        _controller.result != null) {
      final contact = _controller.result!;
      AppState().activeContact = contact;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    }
  }

  void _onBarcodeScanned(BarcodeCapture capture) {
    if (_scanned ||
        _controller.phase == RemotePairPhase.joining ||
        _controller.phase == RemotePairPhase.generating) {
      return;
    }
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.startsWith('wiltkey://pair')) {
        _scanned = true;
        HapticFeedback.mediumImpact();
        try {
          final uri = Uri.parse(rawValue);
          _controller.joinUri(uri);
        } catch (e) {
          _scanned = false;
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: t.action),
        title: Text(
          t.uppercaseLabels
              ? l10n.qrConnectTitle.toUpperCase()
              : l10n.qrConnectTitle,
          style: t.screenTitle.copyWith(fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: t.action,
          labelColor: t.action,
          unselectedLabelColor: t.textTertiary,
          labelStyle: t.sectionLabel.copyWith(fontSize: 11),
          tabs: [
            Tab(
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              text: t.uppercaseLabels
                  ? l10n.qrConnectScanTab.toUpperCase()
                  : l10n.qrConnectScanTab,
            ),
            Tab(
              icon: const Icon(Icons.qr_code, size: 20),
              text: t.uppercaseLabels
                  ? l10n.qrConnectMyCodeTab.toUpperCase()
                  : l10n.qrConnectMyCodeTab,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScanTab(t, l10n),
          _buildMyCodeTab(t, l10n),
        ],
      ),
    );
  }

  Widget _buildScanTab(WiltkeyTokens t, AppLocalizations l10n) {
    if (_controller.phase == RemotePairPhase.joining ||
        _controller.phase == RemotePairPhase.generating) {
      return _buildBusyOverlay(t);
    }

    return Column(
      children: [
        if (_controller.error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(t.radiusCard),
              border: Border.all(color: t.danger.withValues(alpha: 0.3)),
            ),
            child: Text(
              _controller.error!,
              style: TextStyle(color: t.danger, fontSize: 13),
            ),
          ),

        if (!_manualEntry) ...[
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onBarcodeScanned,
                ),
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: t.action, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  l10n.qrConnectScanPrompt,
                  textAlign: TextAlign.center,
                  style: t.bodySecondary.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _manualEntry = true),
                  child: Text(
                    l10n.qrConnectManualPin,
                    style: TextStyle(color: t.action),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: '6-digit PIN',
                      labelStyle: TextStyle(color: t.textSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: t.border),
                        borderRadius: BorderRadius.circular(t.radiusControl),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: t.action),
                        borderRadius: BorderRadius.circular(t.radiusControl),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _hashController,
                    decoration: InputDecoration(
                      labelText: 'Host Identity Fingerprint',
                      labelStyle: TextStyle(color: t.textSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: t.border),
                        borderRadius: BorderRadius.circular(t.radiusControl),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: t.action),
                        borderRadius: BorderRadius.circular(t.radiusControl),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      _controller.join(
                        _pinController.text,
                        _hashController.text,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.action,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(l10n.qrConnectTitle),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _manualEntry = false),
                    child: Text(
                      l10n.qrConnectScanTab,
                      style: TextStyle(color: t.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMyCodeTab(WiltkeyTokens t, AppLocalizations l10n) {
    final payload = _controller.qrPayload;
    final pin = _controller.pin;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.action.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(t.radiusCard),
              border: Border.all(color: t.action.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: t.action, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.qrConnect7DayNotice,
                    style: t.bodySecondary.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          if (payload.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            )
          else
            Container(
              width: 200,
              height: 200,
              alignment: Alignment.center,
              child: CircularProgressIndicator(color: t.action),
            ),

          const SizedBox(height: 24),
          if (pin != null) ...[
            Text(
              'PIN: $pin',
              style: t.screenTitle.copyWith(
                fontSize: 24,
                letterSpacing: 4,
                color: t.action,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _controller.status,
              textAlign: TextAlign.center,
              style: t.bodySecondary.copyWith(fontSize: 12),
            ),
          ],

          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: pin == null
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: payload));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: t.surface,
                        content: Text(
                          l10n.commonCopied,
                          style: TextStyle(color: t.action),
                        ),
                      ),
                    );
                  },
            icon: const Icon(Icons.copy, size: 16),
            label: Text(l10n.commonCopy),
            style: OutlinedButton.styleFrom(
              foregroundColor: t.action,
              side: BorderSide(color: t.action.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusyOverlay(WiltkeyTokens t) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: t.action),
          const SizedBox(height: 20),
          Text(
            _controller.status,
            style: t.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
