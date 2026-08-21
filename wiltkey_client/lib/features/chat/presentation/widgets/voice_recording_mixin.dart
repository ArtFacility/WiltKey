import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart' show Amplitude;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';

import '../../../../core/state.dart';
import '../../../../core/models.dart';
import '../../../../core/payload_limits.dart';
import '../../../../core/theme/wiltkey_tokens.dart';
import '../../../../core/audio/voice_codec.dart';
import '../../../../core/audio/voice_recorder.dart';

/// Shared hold-to-record voice UI + lifecycle, used by both the 1-on-1 and group
/// chat screens. Encapsulates the recorder, the quality tier, the dynamic max
/// duration based on available byte budget / relay limits, slide-to-lock hands-free
/// recording, slide-to-cancel gestures, tactile haptics, and the recording HUD.
mixin VoiceRecordingMixin<T extends StatefulWidget> on State<T> {
  final VoiceRecorder _voiceRecorder = VoiceRecorder();
  static const String _kPrefVoiceQuality = 'wk_voice_quality';

  VoiceQuality _voiceQuality = kVoiceQualityDefault;
  bool _isRecording = false;
  bool _isRecordingLocked = false; // slid up into locked hands-free recording
  bool _voiceCancelArmed = false; // slid far enough left to cancel on release
  bool _voiceStopping = false; // guards a double-stop (auto-cap + release)
  bool _voicePressActive = false; // the finger is still down on the mic
  Duration _voiceElapsed = Duration.zero;
  double _voiceLevel = 0; // 0..1 smoothed mic level for the meter
  Offset _voiceDragOffset = Offset.zero;
  Timer? _voiceTimer;
  StreamSubscription<Amplitude>? _voiceAmpSub;

  /// Anchors the quality popup to the mic icon (a single tap opens it).
  final GlobalKey _voiceMicKey = GlobalKey();

  /// True while a recording is in progress — the host swaps its text field for
  /// [buildRecordingHud] and hides its other composer buttons.
  bool get isRecordingVoice => _isRecording;

  /// True when recording has been locked hands-free.
  bool get isRecordingVoiceLocked => _isRecordingLocked;

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

  // --- Dynamic duration & cost calculations --------------------------------

  /// Computes dynamic maximum voice recording duration allowed by available byte
  /// capacity (contact buffer limit in byte-budget chats and relay envelope limits).
  Duration _maxVoiceDuration() {
    final contact = voiceContact;
    final int byteRate = _voiceQuality.bitRate ~/ 8; // bytes/sec
    if (byteRate <= 0) return const Duration(minutes: 10);

    // Relay envelope limit (5 MB for free tier, 50 MB for Plus)
    final int maxOutgoing = WkPayloadLimits.maxOutgoingPayload;
    // projectedEnvelope(base64Len) = ((base64Len + 2) ~/ 3) * 4 + 256 <= maxOutgoing
    final int maxBase64FromEnvelope = ((maxOutgoing - 256) * 3) ~/ 4;

    int maxBase64Allowed = maxBase64FromEnvelope;

    // Byte budget limit for pad chats / finite group chats
    if (contact != null && !contact.isTimeWilt) {
      // byteCost = base64Len + 73 <= contact.remainingBufferBytes
      final int maxBase64FromBuffer = contact.remainingBufferBytes - 73;
      if (maxBase64FromBuffer < maxBase64Allowed) {
        maxBase64Allowed = maxBase64FromBuffer;
      }
    }

    if (maxBase64Allowed <= 0) return Duration.zero;

    // base64Len = ((rawPayloadBytes + 2) ~/ 3) * 4
    final int maxRawPayload = (maxBase64Allowed * 3) ~/ 4;
    final int maxAudioBytes = maxRawPayload - VoiceHeader.byteLength;
    if (maxAudioBytes <= 0) return Duration.zero;

    // Compute max duration in seconds with 1 second safety margin
    final int rawSeconds = (maxAudioBytes / byteRate).floor();
    final int safeSeconds = rawSeconds > 2 ? rawSeconds - 1 : rawSeconds;

    // Safe ceiling (10 minutes)
    const int maxCapSeconds = 10 * 60;
    return Duration(seconds: safeSeconds.clamp(1, maxCapSeconds));
  }

  /// Estimated pad cost (base64 + envelope overhead) of the recording so far, so
  /// the meter can turn red before the send would overrun the budget.
  int _estimatedVoiceCost() {
    final rawBytes =
        (_voiceQuality.bitRate / 8 * _voiceElapsed.inMilliseconds / 1000)
            .round() +
        VoiceHeader.byteLength;
    final base64Len = ((rawBytes + 2) ~/ 3) * 4;
    return base64Len + 73;
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

  Future<void> _startVoiceRecording() async {
    if (_isRecording) return;
    if (voiceContact == null) return;
    final contact = voiceContact!;
    final maxDuration = _maxVoiceDuration();
    if (!contact.isTimeWilt &&
        (contact.remainingBufferBytes <= 73 + VoiceHeader.byteLength + 100 ||
            maxDuration == Duration.zero)) {
      onVoiceError(
        AppLocalizations.of(context)!.chatVoiceTooLargeSnackBar(
          AppState.formatBytes(73 + VoiceHeader.byteLength + 100),
          AppState.formatBytes(contact.remainingBufferBytes),
        ),
      );
      return;
    }

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

    HapticFeedback.mediumImpact();

    setState(() {
      _isRecording = true;
      _isRecordingLocked = false;
      _voiceCancelArmed = false;
      _voiceStopping = false;
      _voiceElapsed = Duration.zero;
      _voiceLevel = 0;
      _voiceDragOffset = Offset.zero;
    });

    _voiceAmpSub = _voiceRecorder.amplitude().listen((amp) {
      // amp.current is dBFS (~-45 quiet .. 0 loud); map onto 0..1 for the meter.
      final norm = ((amp.current + 45) / 45).clamp(0.0, 1.0);
      if (mounted) setState(() => _voiceLevel = norm);
    });

    _voiceTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _voiceElapsed += const Duration(milliseconds: 100);
      final maxDur = _maxVoiceDuration();
      final cost = _estimatedVoiceCost();
      final c = voiceContact;
      final bool bufferOverrun = c != null &&
          !c.isTimeWilt &&
          cost >= c.remainingBufferBytes - 128;

      if (_voiceElapsed >= maxDur || bufferOverrun) {
        _stopVoiceRecording(cancel: _voiceCancelArmed);
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
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isRecordingLocked = false;
        _voiceCancelArmed = false;
        _voiceDragOffset = Offset.zero;
      });
    }

    HapticFeedback.lightImpact();

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
    if (WkPayloadLimits.exceedsOutgoing(base64Data.length)) {
      onVoiceError(
        WkPayloadLimits.blockedByFreeTier(base64Data.length)
            ? l10n.chatImageNeedsPlusSnackBar
            : l10n.chatImageExceedsMaxSizeSnackBar,
      );
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

  /// Hold to record; release to send; slide up to lock hands-free; slide left to cancel.
  /// When locked, renders a direct Send button. A plain tap opens the quality picker.
  Widget buildVoiceButton(WiltkeyTokens t, AppLocalizations l10n) {
    if (_isRecording && _isRecordingLocked) {
      // Hands-free locked mode: show prominent Send button on the right
      return Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Material(
          color: t.action,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _stopVoiceRecording(cancel: false),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(Icons.send, color: t.onAction, size: 20),
            ),
          ),
        ),
      );
    }

    final isLockNear = _voiceDragOffset.dy < -35;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Floating Lock target above mic button when long-pressing
        if (_isRecording && !_isRecordingLocked)
          Positioned(
            bottom: 48,
            left: -12,
            right: -12,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isLockNear ? t.action : t.surface,
                  borderRadius: BorderRadius.circular(t.radiusPill),
                  border: Border.all(
                    color: isLockNear ? t.action : t.border,
                    width: t.borderWidth,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLockNear ? Icons.lock : Icons.lock_outline,
                      size: 15,
                      color: isLockNear ? t.onAction : t.textSecondary,
                    ),
                    const SizedBox(height: 2),
                    Icon(
                      Icons.keyboard_arrow_up,
                      size: 12,
                      color: isLockNear ? t.onAction : t.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Mic Button
        GestureDetector(
          onTap: () => _showQualityMenu(t, l10n),
          onLongPressStart: (_) {
            _voicePressActive = true;
            _startVoiceRecording();
          },
          onLongPressMoveUpdate: (details) {
            _voiceDragOffset = details.localOffsetFromOrigin;
            // Drag UP to lock hands-free
            if (_voiceDragOffset.dy < -45 && !_isRecordingLocked) {
              _isRecordingLocked = true;
              _voiceCancelArmed = false;
              HapticFeedback.mediumImpact();
              if (mounted) setState(() {});
              return;
            }
            // Drag LEFT to arm cancel
            if (!_isRecordingLocked) {
              final armed = _voiceDragOffset.dx < -55;
              if (armed != _voiceCancelArmed) {
                _voiceCancelArmed = armed;
                HapticFeedback.selectionClick();
                if (mounted) setState(() {});
              }
            }
          },
          onLongPressEnd: (_) {
            _voicePressActive = false;
            if (_isRecordingLocked) {
              // Locked: keep recording hands-free until user taps Send or Cancel
              return;
            }
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
        ),
      ],
    );
  }

  /// Replaces the text field while recording: blink dot, elapsed, level meter /
  /// slide-to-cancel cue, trash/cancel button in locked mode, and live byte cost.
  Widget buildRecordingHud(WiltkeyTokens t, AppLocalizations l10n) {
    final contact = voiceContact;
    final cost = _estimatedVoiceCost();
    final over =
        contact != null &&
        !contact.isTimeWilt &&
        cost > contact.remainingBufferBytes;
    final maxDuration = _maxVoiceDuration();
    final nearCap =
        maxDuration > Duration.zero &&
        (maxDuration - _voiceElapsed) <= const Duration(seconds: 5);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.radiusCard),
        border: Border.all(
          color: _voiceCancelArmed
              ? t.danger
              : (_isRecordingLocked ? t.action : t.border),
          width: t.borderWidth,
        ),
      ),
      child: Row(
        children: [
          // In hands-free locked mode: render Trash button on the left
          if (_isRecordingLocked)
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: IconButton(
                icon: Icon(Icons.delete_outline, color: t.danger, size: 20),
                onPressed: () => _stopVoiceRecording(cancel: true),
                tooltip: l10n.chatVoiceCancel,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ),

          // Blink synced to the 100 ms recording tick
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
              fontSize: 13,
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
                        style: t.bodySecondary.copyWith(
                          color: t.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : (_isRecordingLocked
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(t.radiusPill),
                        child: LinearProgressIndicator(
                          value: _voiceLevel.clamp(0.05, 1.0),
                          minHeight: 4,
                          backgroundColor: t.surfacePressed,
                          color: t.action,
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(t.radiusPill),
                              child: LinearProgressIndicator(
                                value: _voiceLevel.clamp(0.05, 1.0),
                                minHeight: 4,
                                backgroundColor: t.surfacePressed,
                                color: t.action,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chevron_left,
                                size: 14,
                                color: t.textTertiary,
                              ),
                              Text(
                                t.uppercaseLabels
                                    ? l10n.chatVoiceSlideToCancel.toUpperCase()
                                    : l10n.chatVoiceSlideToCancel,
                                style: t.bodySecondary.copyWith(
                                  fontSize: 10,
                                  color: t.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )),
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
