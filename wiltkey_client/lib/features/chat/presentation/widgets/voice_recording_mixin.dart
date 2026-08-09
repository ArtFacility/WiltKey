import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:record/record.dart' show Amplitude;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';

import '../../../../core/state.dart';
import '../../../../core/models.dart';
import '../../../../core/theme/wiltkey_tokens.dart';
import '../../../../core/audio/voice_codec.dart';
import '../../../../core/audio/voice_recorder.dart';

/// Shared hold-to-record voice UI + lifecycle, used by both the 1-on-1 and group
/// chat screens. Encapsulates the recorder, the quality tier, the elapsed/cancel
/// state, the mic button (tap = quality picker, hold = record), and the recording
/// HUD. The host screen wires the four hooks below and drops [buildVoiceButton]
/// into its composer, swapping its text field for [buildRecordingHud] while
/// [isRecordingVoice] is true (the mic button stays mounted so its long-press
/// keeps ownership of the gesture).
mixin VoiceRecordingMixin<T extends StatefulWidget> on State<T> {
  final VoiceRecorder _voiceRecorder = VoiceRecorder();
  static const String _kPrefVoiceQuality = 'wk_voice_quality';

  VoiceQuality _voiceQuality = kVoiceQualityDefault;
  bool _isRecording = false;
  bool _voiceCancelArmed = false; // slid far enough left to cancel on release
  bool _voiceStopping = false; // guards a double-stop (auto-cap + release)
  bool _voicePressActive = false; // the finger is still down on the mic
  Duration _voiceElapsed = Duration.zero;
  double _voiceLevel = 0; // 0..1 smoothed mic level for the meter
  Timer? _voiceTimer;
  StreamSubscription<Amplitude>? _voiceAmpSub;

  /// Anchors the quality popup to the mic icon (a single tap opens it).
  final GlobalKey _voiceMicKey = GlobalKey();

  /// True while a recording is in progress — the host swaps its text field for
  /// [buildRecordingHud] and hides its other composer buttons.
  bool get isRecordingVoice => _isRecording;

  // --- Hooks the host screen provides -------------------------------------

  /// The chat whose budget the recording is charged against (null disables send).
  Contact? get voiceContact;

  /// Send a finished voice payload (already `VoiceHeader`-wrapped + base64) the
  /// same way the host sends any message. Returns an error string or null.
  Future<String?> sendVoiceMessage(String base64Payload, String mimeType);

  /// Show an error to the user (host's snackbar).
  void onVoiceError(String message);

  /// Called after a voice message is queued (host scrolls to bottom, etc.).
  void onVoiceSent();

  /// Called when recording begins (host hides the emoji picker / keyboard).
  void onVoiceRecordingStarted() {}

  // --- Lifecycle (call from the host's initState / dispose) ---------------

  void initVoiceRecording() {
    SharedPreferences.getInstance().then((prefs) {
      final idx = prefs.getInt(_kPrefVoiceQuality);
      if (idx != null && idx >= 0 && idx < VoiceQuality.values.length) {
        if (mounted) setState(() => _voiceQuality = VoiceQuality.values[idx]);
      }
    });
  }

  void disposeVoiceRecording() {
    _voiceTimer?.cancel();
    _voiceAmpSub?.cancel();
    _voiceRecorder.dispose();
  }

  // --- Recording control ---------------------------------------------------

  Future<void> _setVoiceQuality(VoiceQuality q) async {
    if (mounted) setState(() => _voiceQuality = q);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefVoiceQuality, q.index);
  }

  /// A single tap on the mic opens the quality picker anchored to the icon; the
  /// header reminds the user to *hold* to record. Holding skips this entirely and
  /// records straight away with the selected tier.
  Future<void> _showQualityMenu(WiltkeyTokens t, AppLocalizations l10n) async {
    if (_isRecording) return;
    final box = _voiceMicKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlayBox),
        box.localToGlobal(
          box.size.bottomRight(Offset.zero),
          ancestor: overlayBox,
        ),
      ),
      Offset.zero & overlayBox.size,
    );

    final selected = await showMenu<VoiceQuality>(
      context: context,
      position: position,
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusCard),
        side: BorderSide(color: t.border, width: t.borderWidth),
      ),
      items: [
        PopupMenuItem<VoiceQuality>(
          enabled: false,
          height: 30,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic_none_outlined, size: 12, color: t.textTertiary),
              const SizedBox(width: 6),
              Text(
                l10n.chatVoiceHoldHint,
                style: t.bodySecondary.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        for (final q in VoiceQuality.values)
          PopupMenuItem<VoiceQuality>(
            value: q,
            child: Row(
              children: [
                Icon(
                  q == _voiceQuality
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: q == _voiceQuality ? t.action : t.textTertiary,
                ),
                const SizedBox(width: 10),
                Text(
                  t.uppercaseLabels
                      ? _voiceQualityLabel(l10n, q).toUpperCase()
                      : _voiceQualityLabel(l10n, q),
                  style: t.body.copyWith(
                    fontWeight: q == _voiceQuality
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (selected != null) await _setVoiceQuality(selected);
  }

  /// Estimated pad cost (base64 + envelope overhead) of the recording so far, so
  /// the meter can turn red before the send would overrun the budget.
  int _estimatedVoiceCost() {
    final rawBytes =
        (_voiceQuality.bitRate / 8 * _voiceElapsed.inMilliseconds / 1000)
            .round() +
        VoiceHeader.byteLength;
    return (rawBytes * 4 / 3).ceil() + 73;
  }

  Future<void> _startVoiceRecording() async {
    if (_isRecording) return;
    if (voiceContact == null) return;
    onVoiceRecordingStarted();

    final started = await _voiceRecorder.start(_voiceQuality);
    if (!mounted) {
      await _voiceRecorder.cancel();
      return;
    }
    if (!started) {
      onVoiceError(AppLocalizations.of(context)!.chatVoicePermissionDenied);
      return;
    }

    // The press may have ended (or a permission dialog stole it) while start()
    // was awaiting — don't leave a recording running with no gesture to stop it.
    if (!_voicePressActive) {
      await _voiceRecorder.cancel();
      return;
    }

    setState(() {
      _isRecording = true;
      _voiceCancelArmed = false;
      _voiceStopping = false;
      _voiceElapsed = Duration.zero;
      _voiceLevel = 0;
    });

    _voiceAmpSub = _voiceRecorder.amplitude().listen((amp) {
      // amp.current is dBFS (~-45 quiet .. 0 loud); map onto 0..1 for the meter.
      final norm = ((amp.current + 45) / 45).clamp(0.0, 1.0);
      if (mounted) setState(() => _voiceLevel = norm);
    });

    _voiceTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _voiceElapsed += const Duration(milliseconds: 100);
      if (_voiceElapsed >= kVoiceMaxDuration) {
        _stopVoiceRecording(cancel: false); // hit the cap → auto-send
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _stopVoiceRecording({required bool cancel}) async {
    if (!_isRecording || _voiceStopping) return;
    _voiceStopping = true;
    _voiceTimer?.cancel();
    _voiceTimer = null;
    await _voiceAmpSub?.cancel();
    _voiceAmpSub = null;

    final elapsed = _voiceElapsed;
    if (mounted) setState(() => _isRecording = false);

    if (cancel || elapsed < kVoiceMinDuration) {
      await _voiceRecorder.cancel();
      return;
    }

    final capture = await _voiceRecorder.stop();
    if (capture == null || capture.bytes.isEmpty) return;
    await _sendVoice(capture);
  }

  Future<void> _sendVoice(VoiceCapture capture) async {
    final contact = voiceContact;
    if (contact == null) return;

    final payload = VoiceHeader(
      codec: capture.codec,
      duration: capture.duration,
    ).wrap(capture.bytes);
    final base64Data = base64Encode(payload);
    final byteCost = base64Data.length + 73;

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    // Time Wilt has no byte budget (unbounded streaming keystream) — skip the
    // remaining-buffer gate like the image path; the tier cap below still applies.
    if (!contact.isTimeWilt && byteCost > contact.remainingBufferBytes) {
      onVoiceError(
        l10n.chatVoiceTooLargeSnackBar(
          AppState.formatBytes(byteCost),
          AppState.formatBytes(contact.remainingBufferBytes),
        ),
      );
      return;
    }
    if (base64Data.length > 1400000) {
      onVoiceError(l10n.chatImageExceedsMaxSizeSnackBar);
      return;
    }

    final mime = capture.codec == VoiceCodec.opus ? 'audio/ogg' : 'audio/mp4';
    final error = await sendVoiceMessage(base64Data, mime);
    if (error != null && mounted) onVoiceError(error);
    onVoiceSent();
  }

  // --- Composer widgets ----------------------------------------------------

  String _voiceQualityLabel(AppLocalizations l10n, VoiceQuality q) {
    switch (q) {
      case VoiceQuality.lofi:
        return l10n.chatVoiceQualityLofi;
      case VoiceQuality.voice:
        return l10n.chatVoiceQualityVoice;
      case VoiceQuality.clear:
        return l10n.chatVoiceQualityClear;
    }
  }

  String _fmtElapsed(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Hold to record; release to send; slide left past the threshold to cancel.
  /// A plain tap opens the quality picker anchored to the icon.
  Widget buildVoiceButton(WiltkeyTokens t, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => _showQualityMenu(t, l10n),
      onLongPressStart: (_) {
        _voicePressActive = true;
        _startVoiceRecording();
      },
      onLongPressMoveUpdate: (details) {
        final armed = details.localOffsetFromOrigin.dx < -60;
        if (armed != _voiceCancelArmed && mounted) {
          setState(() => _voiceCancelArmed = armed);
        }
      },
      onLongPressEnd: (_) {
        _voicePressActive = false;
        _stopVoiceRecording(cancel: _voiceCancelArmed);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Container(
          key: _voiceMicKey,
          padding: const EdgeInsets.all(8),
          decoration: _isRecording
              ? BoxDecoration(
                  color: _voiceCancelArmed ? t.danger : t.action,
                  shape: BoxShape.circle,
                )
              : null,
          child: Icon(
            _isRecording
                ? (_voiceCancelArmed ? Icons.delete_outline : Icons.mic)
                : Icons.mic_none_outlined,
            color: _isRecording ? t.onAction : t.action,
            size: 22,
          ),
        ),
      ),
    );
  }

  /// Replaces the text field while recording: blink dot, elapsed, level meter (or
  /// a slide-to-cancel hint), and the live pad cost — red once it would overrun.
  Widget buildRecordingHud(WiltkeyTokens t, AppLocalizations l10n) {
    final contact = voiceContact;
    final cost = _estimatedVoiceCost();
    final over =
        contact != null &&
        !contact.isTimeWilt &&
        cost > contact.remainingBufferBytes;
    final nearCap =
        (kVoiceMaxDuration - _voiceElapsed) <= const Duration(seconds: 10);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.radiusCard),
        border: Border.all(
          color: _voiceCancelArmed ? t.danger : t.action,
          width: t.borderWidth,
        ),
      ),
      child: Row(
        children: [
          // Blink synced to the 100 ms recording tick (no extra controller).
          Opacity(
            opacity: (_voiceElapsed.inMilliseconds ~/ 500).isEven ? 1.0 : 0.35,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: t.danger,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmtElapsed(_voiceElapsed),
            style: t.dataMono.copyWith(
              color: nearCap ? t.warning : t.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _voiceCancelArmed
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back, size: 12, color: t.danger),
                      const SizedBox(width: 4),
                      Text(
                        t.uppercaseLabels
                            ? l10n.chatVoiceReleaseCancel.toUpperCase()
                            : l10n.chatVoiceReleaseCancel,
                        style: t.bodySecondary.copyWith(color: t.danger),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(t.radiusPill),
                    child: LinearProgressIndicator(
                      value: _voiceLevel.clamp(0.05, 1.0),
                      minHeight: 4,
                      backgroundColor: t.surfacePressed,
                      color: t.action,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Text(
            AppState.formatBytes(cost),
            style: t.dataMono.copyWith(
              color: over ? t.danger : t.textTertiary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
