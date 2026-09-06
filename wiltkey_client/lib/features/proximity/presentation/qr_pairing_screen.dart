import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/network/qr_pair_controller.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../chat/presentation/chat_screen.dart';

/// Full-screen offline QR connect: a vertical split view — camera on top,
/// our own QR below. Both users scan each other's code; each QR carries the
/// owner's public key, so no relay round-trip is needed at any point.
/// Resulting contact is a 7-day Time Wilt 1:1 chat (same template as before).
class QrPairingScreen extends StatefulWidget {
  const QrPairingScreen({super.key});

  @override
  State<QrPairingScreen> createState() => _QrPairingScreenState();
}

class _QrPairingScreenState extends State<QrPairingScreen> {
  late final QrPairController _controller;
  final MobileScannerController _scannerController = MobileScannerController();
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _controller = QrPairController()..addListener(_onStateChange);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _scannerController.dispose();
    _controller.removeListener(_onStateChange);
    _controller.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted) return;
    setState(() {});

    if (_controller.phase == QrPairPhase.scanned) {
      // Pause the scanner: we hold their pubkey; now they scan ours.
      _scannerController.stop();
      HapticFeedback.mediumImpact();
      _startCooldown();
    } else if (_controller.phase == QrPairPhase.error ||
        _controller.phase == QrPairPhase.idle) {
      _cancelCooldown();
      if (_controller.phase == QrPairPhase.idle ||
          _controller.phase == QrPairPhase.error) {
        _scannerController.start();
      }
    }

    if (_controller.phase == QrPairPhase.success &&
        _controller.result != null) {
      final contact = _controller.result!;
      AppState().activeContact = contact;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 5);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) {
          _cooldownSeconds = 0;
          t.cancel();
        }
      });
    });
  }

  void _cancelCooldown() {
    _cooldownTimer?.cancel();
    _cooldownSeconds = 0;
  }

  void _onBarcodeScanned(BarcodeCapture capture) {
    if (_controller.phase != QrPairPhase.idle) return;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.startsWith('wiltkey://pair')) {
        try {
          _controller.handleScannedUri(Uri.parse(rawValue));
        } catch (_) {
          // Malformed URI — leave the scanner on the next code.
        }
        break;
      }
    }
  }

  /// Controller errors carry either an l10n key (no context there) or a raw
  /// message; map the keys to localized text here.
  String _localizedError(AppLocalizations l10n, String? error) {
    switch (error) {
      case 'qrConnectOutdatedCode':
        return l10n.qrConnectOutdatedCode;
      case 'qrConnectOwnCode':
        return l10n.qrConnectOwnCode;
      case 'qrConnectRechargeBlocked':
        return l10n.qrConnectRechargeBlocked;
      case 'qrConnectAlreadyPaired':
        return l10n.qrConnectAlreadyPaired;
      default:
        return error ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final busy = _controller.phase == QrPairPhase.generating;

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
      ),
      body: Column(
        children: [
          if (_controller.error != null && !busy)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(t.radiusCard),
                border: Border.all(color: t.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _localizedError(l10n, _controller.error),
                      style: TextStyle(color: t.danger, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.refresh, color: t.danger, size: 20),
                    onPressed: () => _controller.reset(),
                  ),
                ],
              ),
            ),

          // --- Top half: camera ---
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onBarcodeScanned,
                ),
                // Scan frame (idle) / scanned checkmark circle (scanned)
                if (_controller.phase == QrPairPhase.scanned)
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child:
                        Icon(Icons.check_circle, color: Colors.green, size: 72),
                  )
                else
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: t.action, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                if (busy)
                  Container(
                    color: t.bg.withValues(alpha: 0.7),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: t.action),
                        const SizedBox(height: 16),
                        Text(
                          _controller.status,
                          style: t.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // --- Bottom half: our QR + state controls ---
          SafeArea(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: _controller.myQrPayload,
                        version: QrVersions.auto,
                        size: 134.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBottomState(t, l10n),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomState(WiltkeyTokens t, AppLocalizations l10n) {
    switch (_controller.phase) {
      case QrPairPhase.scanned:
        final ready = _cooldownSeconds == 0;
        return Column(
          children: [
            Text(
              l10n.qrConnectShowYourCode,
              textAlign: TextAlign.center,
              style: t.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                // 5s cooldown forces reading the "show them your QR" prompt.
                onPressed:
                    ready ? () => _controller.finalizePair() : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.action,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: t.action.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.verified_user, size: 18),
                label: Text(
                  ready
                      ? l10n.qrConnectFinishPairing
                      : '${l10n.qrConnectFinishPairing} ($_cooldownSeconds)',
                ),
              ),
            ),
          ],
        );

      case QrPairPhase.generating:
        return Text(
          _controller.status,
          style: t.bodySecondary.copyWith(fontSize: 13),
        );

      case QrPairPhase.success:
        return Text(
          _controller.status,
          style: t.bodySecondary.copyWith(fontSize: 13),
        );

      case QrPairPhase.idle:
      case QrPairPhase.error:
        return Column(
          children: [
            Text(
              l10n.qrConnectScanPrompt,
              textAlign: TextAlign.center,
              style: t.bodySecondary.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.qrConnect7DayNotice,
              textAlign: TextAlign.center,
              style: t.bodySecondary.copyWith(
                fontSize: 11,
                color: t.textTertiary,
              ),
            ),
          ],
        );
    }
  }
}
