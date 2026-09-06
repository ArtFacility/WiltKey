import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/payload_limits.dart';
import 'package:wiltkey_client/core/state.dart';
import 'package:wiltkey_client/core/theme/wk.dart';
import 'package:wiltkey_client/core/theme/wiltkey_tokens.dart';
import 'package:wiltkey_client/core/video/video_message_service.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';

/// Result returned from the video send preview dialog.
class VideoSendResult {
  final VideoMessagePayload payload;
  final File file;
  final bool allowSave;
  final bool ephemeral;
  final int ttlSeconds;

  const VideoSendResult({
    required this.payload,
    required this.file,
    required this.allowSave,
    this.ephemeral = false,
    this.ttlSeconds = 0,
  });
}

/// Interactive video compression preview & send confirmation dialog.
class VideoSendDialog extends StatefulWidget {
  final String sourcePath;
  final Contact? contact; // null for group chats

  const VideoSendDialog({
    super.key,
    required this.sourcePath,
    this.contact,
  });

  static Future<VideoSendResult?> show(
    BuildContext context, {
    required String sourcePath,
    Contact? contact,
  }) {
    return showDialog<VideoSendResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VideoSendDialog(
        sourcePath: sourcePath,
        contact: contact,
      ),
    );
  }

  @override
  State<VideoSendDialog> createState() => _VideoSendDialogState();
}

class _VideoSendDialogState extends State<VideoSendDialog> {
  bool _previewLoading = true;
  bool _compressing = false;
  String? _errorMessage;
  VideoPrepareResult? _result;
  VideoPlayerController? _playerController;

  double _totalDurationSecs = 0.0;
  double _trimStart = 0.0;
  double _trimEnd = 0.0;

  bool _allowSave = false;
  bool _ephemeral = false;
  double _ttlSeconds = 10;
  bool _sent = false;

  /// Compression tier chosen in the dialog. Maps: Low→360p, Medium→640p,
  /// High→720p (plugin's DefaultQuality tier — its literal HighQuality tier
  /// forces a 3.7Mbps builder that blows past the encrypted payload cap).
  VideoQuality _selectedQuality = VideoQuality.MediumQuality;

  bool _isSeeking = false;

  @override
  void initState() {
    super.initState();
    _initPreview();
  }

  @override
  void dispose() {
    _playerController?.removeListener(_onPlayerTick);
    _playerController?.dispose();
    if (!_sent) {
      try {
        _result?.file.delete();
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _initPreview() async {
    try {
      final controller = VideoPlayerController.file(File(widget.sourcePath));
      await controller.initialize();
      final totalSecs = max(0.0, controller.value.duration.inMilliseconds / 1000.0);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _playerController = controller;
        _totalDurationSecs = totalSecs;
        _trimStart = 0.0;
        _trimEnd = (totalSecs > 0) ? min(15.0, totalSecs) : 15.0;
        _previewLoading = false;
      });
      controller.setLooping(false);
      controller.addListener(_onPlayerTick);
      controller.play();
    } catch (e) {
      if (mounted) {
        setState(() {
          _previewLoading = false;
          _errorMessage = 'Failed to load video: $e';
        });
      }
    }
  }

  void _onPlayerTick() async {
    final controller = _playerController;
    if (controller == null || !controller.value.isInitialized || _isSeeking) return;
    final posSecs = controller.value.position.inMilliseconds / 1000.0;
    if (posSecs >= _trimEnd || posSecs < _trimStart - 0.2) {
      _isSeeking = true;
      try {
        await controller.seekTo(Duration(milliseconds: (_trimStart * 1000).round()));
        if (mounted && !controller.value.isPlaying) {
          await controller.play();
        }
      } catch (_) {} finally {
        _isSeeking = false;
      }
    }
  }

  void _onTrimChanged(RangeValues values) {
    final maxLimit = max(1.5, _totalDurationSecs);
    double start = values.start.clamp(0.0, maxLimit);
    double end = values.end.clamp(0.0, maxLimit);

    // Enforce 15.0s maximum duration
    if (end - start > 15.0) {
      if ((start - _trimStart).abs() > (end - _trimEnd).abs()) {
        end = min(maxLimit, start + 15.0);
      } else {
        start = max(0.0, end - 15.0);
      }
    }
    // Enforce 1.0s minimum duration
    if (end - start < 1.0) {
      if (start + 1.0 <= maxLimit) {
        end = start + 1.0;
      } else {
        start = max(0.0, end - 1.0);
      }
    }

    start = start.clamp(0.0, maxLimit);
    end = end.clamp(start, maxLimit);

    setState(() {
      _trimStart = start;
      _trimEnd = end;
      if (_result != null) {
        try {
          _result?.file.delete();
        } catch (_) {}
        _result = null;
      }
    });

    _playerController?.seekTo(Duration(milliseconds: (start * 1000).round()));
  }

  Future<void> _handleSend() async {
    final l10n = AppLocalizations.of(context)!;
    if (_result != null) {
      _sent = true;
      Navigator.pop(
        context,
        VideoSendResult(
          payload: _result!.payload,
          file: _result!.file,
          allowSave: _allowSave,
          ephemeral: _ephemeral,
          ttlSeconds: _ephemeral ? _ttlSeconds.round() : 0,
        ),
      );
      return;
    }

    setState(() {
      _compressing = true;
      _errorMessage = null;
    });
    _playerController?.pause();

    final durSecs = max(1, (_trimEnd - _trimStart).round());
    final startSecs = _trimStart.round();

    final result = await VideoMessageService.prepareVideo(
      widget.sourcePath,
      startTime: startSecs,
      duration: durSecs,
      quality: _selectedQuality,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _compressing = false;
        _errorMessage = l10n.chatVideoCompressionFailed;
      });
      return;
    }

    final payloadJsonLen = result.payload.toJsonString().length;
    final byteCost = payloadJsonLen + 73;
    final contact = widget.contact;
    final isGroup = contact?.isGroup ?? false;
    final isTimeWilt1on1 = !isGroup && (contact?.isTimeWilt ?? false);
    final bool exceedsPad = contact != null &&
        !isTimeWilt1on1 &&
        byteCost > contact.remainingBufferBytes;
    final bool exceedsMaxPayload = WkPayloadLimits.exceedsOutgoing(payloadJsonLen);

    if (exceedsPad || exceedsMaxPayload) {
      setState(() {
        _compressing = false;
        _result = result;
      });
      return;
    }

    _sent = true;
    Navigator.pop(
      context,
      VideoSendResult(
        payload: result.payload,
        file: result.file,
        allowSave: _allowSave,
        ephemeral: _ephemeral,
        ttlSeconds: _ephemeral ? _ttlSeconds.round() : 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;

    if (_previewLoading) {
      return Dialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(t.action),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading video...',
                style: t.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    if (_compressing) {
      return Dialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(t.warning),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.chatVideoCompressing,
                style: t.body.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Optimizing for encrypted transit',
                style: t.bodySecondary.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return AlertDialog(
        backgroundColor: t.surface,
        title: Text(l10n.chatVideoError, style: t.screenTitle),
        content: SelectableText(_errorMessage ?? 'Unknown error', style: t.body),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _errorMessage = null);
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      );
    }

    final selectedSecs = (_trimEnd - _trimStart).clamp(1.0, 15.0);
    final int estimatedSizeBytes = _result != null
        ? _result!.sizeBytes
        : VideoMessageService.estimateCompressedBytes(
            selectedSecs.round(), _selectedQuality);
    final int payloadJsonLen = _result != null
        ? _result!.payload.toJsonString().length
        : (estimatedSizeBytes * 1.37).round() + 5000;
    final int byteCost = payloadJsonLen + 73;

    // Pad / keystream lane space verification
    final contact = widget.contact;
    final isGroup = contact?.isGroup ?? false;
    final isTimeWilt1on1 = !isGroup && (contact?.isTimeWilt ?? false);
    final bool exceedsPad = contact != null &&
        !isTimeWilt1on1 &&
        byteCost > contact.remainingBufferBytes;

    final bool exceedsMaxPayload = WkPayloadLimits.exceedsOutgoing(payloadJsonLen);

    return Dialog(
      backgroundColor: t.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusCard),
        side: BorderSide(color: t.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t.uppercaseLabels
                          ? l10n.chatVideoSelectSourceTitle.toUpperCase()
                          : l10n.chatVideoSelectSourceTitle,
                      style: t.screenTitle.copyWith(fontSize: 16),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: t.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Video Preview Player Box
                ClipRRect(
                  borderRadius: BorderRadius.circular(t.radiusControl),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 280),
                    color: Colors.black,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: (_playerController != null &&
                                _playerController!.value.isInitialized &&
                                !_playerController!.value.hasError &&
                                _playerController!.value.aspectRatio > 0 &&
                                _playerController!.value.aspectRatio.isFinite)
                            ? _playerController!.value.aspectRatio
                            : 16 / 9,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_playerController != null &&
                                _playerController!.value.isInitialized &&
                                !_playerController!.value.hasError)
                              VideoPlayer(_playerController!)
                            else
                              Container(color: Colors.black26),
                            GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            if (_playerController == null) return;
                            setState(() {
                              if (_playerController!.value.isPlaying) {
                                _playerController!.pause();
                              } else {
                                _playerController!.play();
                              }
                            });
                          },
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: (_playerController != null &&
                                      !_playerController!.value.isPlaying)
                                  ? 1.0
                                  : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white30),
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

                // Trimmer Controls
                _buildTrimmer(t),
                const SizedBox(height: 12),

                // Quality tier
                _buildQualitySelector(t),
                const SizedBox(height: 12),

                // Stats badges row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildStatChip(
                      t,
                      icon: Icons.data_usage_outlined,
                      label: _result != null
                          ? AppState.formatBytes(_result!.sizeBytes)
                          : '~${AppState.formatBytes(estimatedSizeBytes)} (est.)',
                    ),
                    _buildStatChip(
                      t,
                      icon: Icons.timer_outlined,
                      label: '${selectedSecs.toStringAsFixed(1)}s',
                    ),
                    if (contact != null && !isTimeWilt1on1)
                      _buildStatChip(
                        t,
                        icon: isGroup ? Icons.lan_outlined : Icons.vpn_key_outlined,
                        label: isGroup
                            ? 'Lane: ${AppState.formatBytes(contact.remainingBufferBytes)}'
                            : 'Pad: ${AppState.formatBytes(contact.remainingBufferBytes)}',
                        isWarning: exceedsPad,
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Exceeds pad warning banner
                if (exceedsPad) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(t.radiusControl),
                      border: Border.all(color: t.warning.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: t.warning, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.chatImageTooLargeSnackBar(
                              AppState.formatBytes(byteCost),
                              AppState.formatBytes(contact.remainingBufferBytes),
                            ),
                            style: t.bodySecondary.copyWith(
                              color: t.warning,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (exceedsMaxPayload) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(t.radiusControl),
                      border: Border.all(color: t.warning.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      l10n.chatVideoTooLarge(AppState.formatBytes(estimatedSizeBytes)),
                      style: t.bodySecondary.copyWith(color: t.warning, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Toggles: Allow Save & Ephemeral
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: t.action,
                  title: Text(
                    l10n.chatImageCompressionAllowDownload,
                    style: t.body.copyWith(fontSize: 14),
                  ),
                  subtitle: Text(
                    'Let recipient export this video to their photos',
                    style: t.bodySecondary.copyWith(fontSize: 12),
                  ),
                  value: _allowSave,
                  onChanged: _ephemeral
                      ? null
                      : (val) => setState(() => _allowSave = val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: t.action,
                  title: Text(
                    l10n.chatImageCompressionWilting,
                    style: t.body.copyWith(fontSize: 14),
                  ),
                  subtitle: Text(
                    'Deletes after being opened and played',
                    style: t.bodySecondary.copyWith(fontSize: 12),
                  ),
                  value: _ephemeral,
                  onChanged: (val) => setState(() {
                    _ephemeral = val;
                    if (val) _allowSave = false;
                  }),
                ),

                if (_ephemeral) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Self-destruct timer', style: t.bodySecondary.copyWith(fontSize: 12)),
                        Text('${_ttlSeconds.round()}s', style: t.dataMono.copyWith(fontSize: 12, color: t.action)),
                      ],
                    ),
                  ),
                  Slider(
                    value: _ttlSeconds,
                    min: 5,
                    max: 60,
                    divisions: 11,
                    activeColor: t.action,
                    onChanged: (val) => setState(() => _ttlSeconds = val),
                  ),
                ],
                const SizedBox(height: 16),

                // Send & Cancel Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        l10n.chatVoiceCancel,
                        style: t.bodySecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (exceedsPad || exceedsMaxPayload)
                            ? t.textTertiary.withValues(alpha: 0.2)
                            : t.action,
                        foregroundColor: (exceedsPad || exceedsMaxPayload)
                            ? t.textTertiary
                            : t.onAction,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(t.radiusControl),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: (exceedsPad || exceedsMaxPayload)
                          ? null
                          : _handleSend,
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: Text(l10n.chatVoiceSend),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQualitySelector(WiltkeyTokens t) {
    final l10n = AppLocalizations.of(context)!;
    final options = <(VideoQuality, String, String)>[
      (VideoQuality.LowQuality, l10n.chatVideoQualityLow, '~80 KB/s'),
      (VideoQuality.MediumQuality, l10n.chatVideoQualityMedium, '~160 KB/s'),
      (VideoQuality.DefaultQuality, l10n.chatVideoQualityHigh, '~380 KB/s'),
    ];
    return Row(
      children: [
        Icon(Icons.tune, size: 14, color: t.action),
        const SizedBox(width: 6),
        Text(
          t.uppercaseLabels
              ? l10n.chatVideoQualityLabel.toUpperCase()
              : l10n.chatVideoQualityLabel,
          style:
              t.bodySecondary.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              for (final (quality, label, rate) in options) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (quality == _selectedQuality) return;
                      setState(() {
                        _selectedQuality = quality;
                        // Size estimate changed — drop any stale compression.
                        if (_result != null) {
                          try {
                            _result?.file.delete();
                          } catch (_) {}
                          _result = null;
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: quality == _selectedQuality
                            ? t.action.withValues(alpha: 0.14)
                            : t.surface,
                        border: Border.all(
                          color: quality == _selectedQuality
                              ? t.action
                              : t.border,
                          width: quality == _selectedQuality ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(t.radiusControl),
                      ),
                      child: Column(
                        children: [
                          Text(
                            label,
                            style: t.body.copyWith(
                              fontSize: 11,
                              fontWeight: quality == _selectedQuality
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: quality == _selectedQuality
                                  ? t.action
                                  : t.textSecondary,
                            ),
                          ),
                          Text(
                            rate,
                            style: t.dataMono.copyWith(
                              fontSize: 8.5,
                              color: t.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (quality != options.last.$1) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrimmer(WiltkeyTokens t) {
    if (_totalDurationSecs <= 1.5) return const SizedBox.shrink();

    final safeMax = max(1.5, _totalDurationSecs);
    final safeStart = _trimStart.clamp(0.0, safeMax - 0.1);
    final safeEnd = _trimEnd.clamp(safeStart + 0.1, safeMax);
    final selectedDuration = (safeEnd - safeStart).clamp(0.0, 15.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.content_cut_rounded, size: 14, color: t.action),
                const SizedBox(width: 6),
                Text(
                  'Trim Clip',
                  style: t.bodySecondary.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Text(
              '${selectedDuration.toStringAsFixed(1)}s / 15s max',
              style: t.dataMono.copyWith(
                fontSize: 11,
                color: selectedDuration > 14.5 ? t.warning : t.action,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: t.action,
            inactiveTrackColor: t.border,
            thumbColor: t.action,
            overlayColor: t.action.withValues(alpha: 0.15),
            trackHeight: 4,
            rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: RangeSlider(
            values: RangeValues(safeStart, safeEnd),
            min: 0.0,
            max: safeMax,
            onChanged: _onTrimChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatSecs(safeStart),
              style: t.dataMono.copyWith(fontSize: 10, color: t.textTertiary),
            ),
            Text(
              _formatSecs(safeEnd),
              style: t.dataMono.copyWith(fontSize: 10, color: t.textTertiary),
            ),
          ],
        ),
      ],
    );
  }

  String _formatSecs(double secs) {
    final m = (secs / 60).floor();
    final s = secs % 60;
    return '$m:${s.toStringAsFixed(1).padLeft(4, '0')}';
  }

  Widget _buildStatChip(
    WiltkeyTokens t, {
    required IconData icon,
    required String label,
    bool isWarning = false,
  }) {
    final color = isWarning ? t.warning : t.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isWarning
            ? t.warning.withValues(alpha: 0.12)
            : t.surface,
        borderRadius: BorderRadius.circular(t.radiusPill),
        border: Border.all(
          color: isWarning
              ? t.warning.withValues(alpha: 0.4)
              : t.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: t.dataMono.copyWith(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}
