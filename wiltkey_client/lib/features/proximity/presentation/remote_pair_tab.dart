// TEMPORARY — remove after Google Play production approval (see kRemotePairingTesting).
//
// The debug-only "Remote" pairing tab. Purely functional: host shows their
// identity hash + a PIN to read out; the other tester pastes both and connects.
// No animations — this exists solely so scattered closed testers can chat.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiltkey_client/core/network/remote_pairing_controller.dart';
import 'package:wiltkey_client/core/theme/wk.dart';
import 'package:wiltkey_client/core/theme/wiltkey_tokens.dart';

class RemotePairTab extends StatefulWidget {
  const RemotePairTab({super.key});

  @override
  State<RemotePairTab> createState() => _RemotePairTabState();
}

class _RemotePairTabState extends State<RemotePairTab> {
  final RemotePairingController _controller = RemotePairingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _hashController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _pinController.dispose();
    _hashController.dispose();
    super.dispose();
  }

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          color: t.bg,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _warningBanner(t),
                const SizedBox(height: 16),
                if (_controller.phase == RemotePairPhase.generating ||
                    _controller.phase == RemotePairPhase.success)
                  _statusCard(t)
                else ...[
                  _hostSection(t),
                  const SizedBox(height: 24),
                  _joinSection(t),
                  if (_controller.error != null) ...[
                    const SizedBox(height: 16),
                    _errorCard(t),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _warningBanner(WiltkeyTokens t) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.warning.withValues(alpha: 0.10),
        border: Border.all(color: t.warning.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, color: t.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Testing only. Pairs over the relay instead of in person — this '
              'trusts the relay. Both testers must be on the SAME relay. '
              'Creates a 20 MB pad.',
              style: t.bodySecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Host --------------------------------------------------------------

  Widget _hostSection(WiltkeyTokens t) {
    final hosting = _controller.phase == RemotePairPhase.hosting;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(t.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(t, 'Receive a contact', Icons.wifi_tethering),
          const SizedBox(height: 4),
          Text(
            'Give the other tester BOTH values below. They paste them into '
            '“Connect to a host”.',
            style: t.bodySecondary,
          ),
          const SizedBox(height: 14),
          _copyField(t, 'Your identity hash', _controller.myHash),
          const SizedBox(height: 12),
          if (hosting && _controller.pin != null)
            _pinDisplay(t, _controller.pin!)
          else
            Text('PIN', style: t.sectionLabel),
          const SizedBox(height: 12),
          Text(_controller.status, style: t.bodySecondary),
          const SizedBox(height: 12),
          if (hosting)
            OutlinedButton.icon(
              onPressed: _controller.reset,
              icon: const Icon(Icons.stop, size: 16),
              label: const Text('Stop hosting'),
              style: OutlinedButton.styleFrom(foregroundColor: t.danger),
            )
          else
            ElevatedButton.icon(
              onPressed: _controller.busy ? null : _controller.startHosting,
              icon: const Icon(Icons.wifi_tethering, size: 16),
              label: const Text('Start & show PIN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: t.action,
                foregroundColor: t.bg,
              ),
            ),
        ],
      ),
    );
  }

  Widget _pinDisplay(WiltkeyTokens t, String pin) {
    return Row(
      children: [
        Expanded(
          child: Text(
            pin,
            style: t.screenTitle.copyWith(
              fontSize: 32,
              letterSpacing: 8,
              color: t.action,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.copy, color: t.action, size: 20),
          onPressed: () => _copy(pin, 'PIN'),
        ),
      ],
    );
  }

  // ---- Join --------------------------------------------------------------

  Widget _joinSection(WiltkeyTokens t) {
    final joining = _controller.phase == RemotePairPhase.joining;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(t.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(t, 'Connect to a host', Icons.link),
          const SizedBox(height: 14),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: t.body,
            decoration: _fieldDecoration(t, 'PIN (6 digits)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _hashController,
            style: t.body.copyWith(fontFamily: 'monospace', fontSize: 12),
            minLines: 1,
            maxLines: 2,
            decoration: _fieldDecoration(t, 'Host identity hash (64 chars)'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: joining || _controller.busy
                ? null
                : () => _controller.join(
                    _pinController.text,
                    _hashController.text,
                  ),
            icon: joining
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link, size: 16),
            label: Text(joining ? 'Connecting…' : 'Connect'),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.action,
              foregroundColor: t.bg,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Status / error ----------------------------------------------------

  Widget _statusCard(WiltkeyTokens t) {
    final done = _controller.phase == RemotePairPhase.success;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: done ? t.positive : t.action),
        borderRadius: BorderRadius.circular(t.radiusCard),
      ),
      child: Column(
        children: [
          Icon(
            done ? Icons.check_circle_outline : Icons.hourglass_top,
            color: done ? t.positive : t.action,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            done
                ? 'Paired with ${_controller.result?.name ?? 'contact'}'
                : _controller.status,
            style: t.body,
            textAlign: TextAlign.center,
          ),
          if (!done) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _controller.padProgress > 0 ? _controller.padProgress : null,
              backgroundColor: t.border,
              color: t.action,
            ),
            const SizedBox(height: 8),
            Text(
              'Keep this screen open until it finishes.',
              style: t.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
          if (done) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _pinController.clear();
                _hashController.clear();
                _controller.reset();
              },
              style: OutlinedButton.styleFrom(foregroundColor: t.action),
              child: const Text('Done'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorCard(WiltkeyTokens t) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.danger.withValues(alpha: 0.10),
        border: Border.all(color: t.danger),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: t.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _controller.error ?? '',
              style: t.bodySecondary.copyWith(color: t.danger),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Small helpers -----------------------------------------------------

  Widget _sectionTitle(WiltkeyTokens t, String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: t.action, size: 18),
        const SizedBox(width: 8),
        Text(text, style: t.screenTitle.copyWith(fontSize: 16)),
      ],
    );
  }

  Widget _copyField(WiltkeyTokens t, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.sectionLabel),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: t.bg,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(t.radiusControl),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: t.body.copyWith(fontFamily: 'monospace', fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy, color: t.action, size: 18),
                onPressed: () => _copy(value, label),
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(WiltkeyTokens t, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: t.bodySecondary,
      filled: true,
      fillColor: t.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(t.radiusControl),
        borderSide: BorderSide(color: t.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(t.radiusControl),
        borderSide: BorderSide(color: t.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(t.radiusControl),
        borderSide: BorderSide(color: t.action),
      ),
    );
  }
}
