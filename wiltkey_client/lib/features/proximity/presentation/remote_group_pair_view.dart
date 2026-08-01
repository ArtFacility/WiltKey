// TEMPORARY — remove after Google Play production approval (see kRemotePairingTesting).
//
// Debug-only remote GROUP pairing UI: a host screen (invite a remote member into
// a group) and a joiner screen (join a remote group from a PIN + host hash).
// Both are purely functional and reuse RemotePairingController's group flow.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/network/remote_pairing_controller.dart';
import 'package:wiltkey_client/core/theme/wk.dart';
import 'package:wiltkey_client/core/theme/wiltkey_tokens.dart';

/// Host side: advertise a group invite over the relay.
class RemoteGroupInviteView extends StatefulWidget {
  final Contact group;
  const RemoteGroupInviteView({super.key, required this.group});

  @override
  State<RemoteGroupInviteView> createState() => _RemoteGroupInviteViewState();
}

class _RemoteGroupInviteViewState extends State<RemoteGroupInviteView> {
  final RemotePairingController _c = RemotePairingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _copy(String v, String label) {
    Clipboard.setData(ClipboardData(text: v));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        title: Text('Remote invite (testing)',
            style: t.screenTitle.copyWith(fontSize: 16)),
      ),
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final hosting = _c.phase == RemotePairPhase.hosting;
          final done = _c.phase == RemotePairPhase.success;
          final working = _c.phase == RemotePairPhase.generating;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                remotePairWarning(t, 'Invites ${widget.group.name} over the relay '
                    'instead of in person. Both testers must be on the same relay.'),
                const SizedBox(height: 16),
                if (done)
                  remoteStatusCard(t, done: true, text: _c.status)
                else if (working)
                  remoteStatusCard(t, done: false, text: _c.status, progress: _c.padProgress)
                else ...[
                  Text('Give the joiner BOTH values, then keep this screen open.',
                      style: t.bodySecondary),
                  const SizedBox(height: 14),
                  remoteCopyField(t, 'Your identity hash', _c.myHash,
                      () => _copy(_c.myHash, 'Hash')),
                  const SizedBox(height: 12),
                  if (hosting && _c.pin != null)
                    remotePinDisplay(t, _c.pin!, () => _copy(_c.pin!, 'PIN'))
                  else
                    Text('PIN', style: t.sectionLabel),
                  const SizedBox(height: 12),
                  Text(_c.status, style: t.bodySecondary),
                  if (_c.error != null) ...[
                    const SizedBox(height: 12),
                    remoteErrorCard(t, _c.error!),
                  ],
                  const SizedBox(height: 16),
                  if (hosting)
                    OutlinedButton.icon(
                      onPressed: _c.reset,
                      icon: const Icon(Icons.stop, size: 16),
                      label: const Text('Stop'),
                      style: OutlinedButton.styleFrom(foregroundColor: t.danger),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _c.busy
                          ? null
                          : () => _c.startHostingGroup(widget.group),
                      icon: const Icon(Icons.wifi_tethering, size: 16),
                      label: const Text('Start & show PIN'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: t.action, foregroundColor: t.bg),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Joiner side: join a remote group from a PIN + the host's identity hash.
class RemoteGroupJoinView extends StatefulWidget {
  const RemoteGroupJoinView({super.key});

  @override
  State<RemoteGroupJoinView> createState() => _RemoteGroupJoinViewState();
}

class _RemoteGroupJoinViewState extends State<RemoteGroupJoinView> {
  final RemotePairingController _c = RemotePairingController();
  final TextEditingController _pin = TextEditingController();
  final TextEditingController _hash = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    _pin.dispose();
    _hash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        title: Text('Join remote group (testing)',
            style: t.screenTitle.copyWith(fontSize: 16)),
      ),
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final busy = _c.phase == RemotePairPhase.joining ||
              _c.phase == RemotePairPhase.generating;
          final done = _c.phase == RemotePairPhase.success;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                remotePairWarning(t, 'Joins a group over the relay instead of in '
                    'person. You must be on the same relay as the host.'),
                const SizedBox(height: 16),
                if (done)
                  remoteStatusCard(t, done: true, text: _c.status)
                else if (busy)
                  remoteStatusCard(t, done: false, text: _c.status, progress: _c.padProgress)
                else ...[
                  TextField(
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: t.body,
                    decoration: remoteFieldDecoration(t, 'PIN (6 digits)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _hash,
                    style: t.body.copyWith(fontFamily: 'monospace', fontSize: 12),
                    minLines: 1,
                    maxLines: 2,
                    decoration:
                        remoteFieldDecoration(t, 'Host identity hash (64 chars)'),
                  ),
                  if (_c.error != null) ...[
                    const SizedBox(height: 12),
                    remoteErrorCard(t, _c.error!),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _c.busy
                        ? null
                        : () => _c.joinGroup(_pin.text, _hash.text),
                    icon: const Icon(Icons.group_add, size: 16),
                    label: const Text('Join group'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: t.action, foregroundColor: t.bg),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---- Shared bits (also used by the 1-on-1 tab's visual language) -----------

Widget remotePairWarning(WiltkeyTokens t, String text) => Container(
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
          Expanded(child: Text(text, style: t.bodySecondary)),
        ],
      ),
    );

Widget remoteCopyField(
        WiltkeyTokens t, String label, String value, VoidCallback onCopy) =>
    Column(
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
                child: Text(value,
                    style: t.body.copyWith(fontFamily: 'monospace', fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: Icon(Icons.copy, color: t.action, size: 18),
                onPressed: onCopy,
              ),
            ],
          ),
        ),
      ],
    );

Widget remotePinDisplay(WiltkeyTokens t, String pin, VoidCallback onCopy) => Row(
      children: [
        Expanded(
          child: Text(pin,
              style: t.screenTitle
                  .copyWith(fontSize: 32, letterSpacing: 8, color: t.action)),
        ),
        IconButton(
          icon: Icon(Icons.copy, color: t.action, size: 20),
          onPressed: onCopy,
        ),
      ],
    );

Widget remoteStatusCard(WiltkeyTokens t,
        {required bool done, required String text, double progress = 0}) =>
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: done ? t.positive : t.action),
        borderRadius: BorderRadius.circular(t.radiusCard),
      ),
      child: Column(
        children: [
          Icon(done ? Icons.check_circle_outline : Icons.hourglass_top,
              color: done ? t.positive : t.action, size: 40),
          const SizedBox(height: 12),
          Text(text, style: t.body, textAlign: TextAlign.center),
          if (!done) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              backgroundColor: t.border,
              color: t.action,
            ),
          ],
        ],
      ),
    );

Widget remoteErrorCard(WiltkeyTokens t, String error) => Container(
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
            child: Text(error, style: t.bodySecondary.copyWith(color: t.danger)),
          ),
        ],
      ),
    );

InputDecoration remoteFieldDecoration(WiltkeyTokens t, String hint) =>
    InputDecoration(
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
