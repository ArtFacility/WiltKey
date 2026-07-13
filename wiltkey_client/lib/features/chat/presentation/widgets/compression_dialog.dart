import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/state.dart';
import '../../../../core/image_utils.dart';
import '../../../../core/theme/wk.dart';

/// Result of the compression dialog: the chosen quality (0.1-1.0), whether the
/// image should be sent hidden (tap-to-reveal spoiler), whether the recipient is
/// allowed to save/download it — and the **already-compressed WebP bytes** ready
/// to base64 + send (the caller must NOT recompress).
class CompressionResult {
  final double quality;
  final bool hidden;
  final bool allowSave;
  final Uint8List bytes;
  // Wilting (disappearing) image: hides behind a reveal gate, runs a countdown
  // once opened, then its stored bytes are destroyed. Mutually exclusive with
  // [allowSave] (a wilting image can't be downloadable) and [hidden] (the wilt
  // gate is its own reveal). [ttlSeconds] is its lifetime once opened (1–60).
  final bool ephemeral;
  final int ttlSeconds;
  const CompressionResult({
    required this.quality,
    required this.hidden,
    required this.allowSave,
    required this.bytes,
    this.ephemeral = false,
    this.ttlSeconds = 0,
  });
}

/// Image send dialog. Unlike the old version — which *guessed* the sent size from
/// the original file size — this actually runs [ImageUtils.prepareForSend] (the
/// exact send-time pipeline: downscale to ≤2000px + WebP re-encode) so the shown
/// "estimated size / charge" is the real number, not a wild over-estimate. The
/// compressed bytes it computes are returned so the send path reuses them.
class CompressionDialog extends StatefulWidget {
  final Uint8List originalBytes;

  const CompressionDialog({super.key, required this.originalBytes});

  static Future<CompressionResult?> show(
    BuildContext context,
    Uint8List originalBytes,
  ) {
    return showDialog<CompressionResult>(
      context: context,
      builder: (context) => CompressionDialog(originalBytes: originalBytes),
    );
  }

  @override
  State<CompressionDialog> createState() => _CompressionDialogState();
}

class _CompressionDialogState extends State<CompressionDialog> {
  double quality = 0.5;
  bool hidden = false;
  bool allowSave = false;
  bool ephemeral = false;
  double ttl = 5; // wilting lifetime in seconds (1–60), once opened

  // Live compression state: the actual WebP bytes for the last settled quality.
  Uint8List? _compressed;
  int _compressedForQuality = -1; // quality (0-100) the cached bytes belong to
  bool _busy = false;
  Timer? _debounce;
  int _seq = 0; // guards against out-of-order slider recomputes

  int get _qInt => (quality * 100).round();

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleRecompute() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _recompute);
  }

  /// Compress the source at the current quality and cache the result. Only the
  /// newest invocation's result is applied (seq guard), so dragging the slider
  /// doesn't paint a stale size.
  Future<void> _recompute() async {
    final int seq = ++_seq;
    final int q = _qInt;
    if (mounted) setState(() => _busy = true);
    Uint8List out;
    try {
      out = await ImageUtils.prepareForSend(widget.originalBytes, quality: q);
    } catch (_) {
      out = widget.originalBytes;
    }
    if (!mounted || seq != _seq) return; // superseded by a newer recompute
    setState(() {
      _compressed = out;
      _compressedForQuality = q;
      _busy = false;
    });
  }

  /// base64 length for [n] raw bytes (inflates ~4/3), + 73 bytes frame overhead.
  int _chargeFor(int n) => ((n + 2) ~/ 3) * 4 + 73;

  Future<void> _onSend() async {
    // Guarantee the returned bytes match the currently-shown quality.
    final int q = _qInt;
    Uint8List out;
    if (_compressed != null && _compressedForQuality == q) {
      out = _compressed!;
    } else {
      out = await ImageUtils.prepareForSend(widget.originalBytes, quality: q);
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      CompressionResult(
        quality: quality,
        hidden: hidden,
        allowSave: allowSave,
        bytes: out,
        ephemeral: ephemeral,
        ttlSeconds: ephemeral ? ttl.round() : 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final int originalSize = widget.originalBytes.length;

    final bool ready = _compressed != null;
    final int? estimatedSize = ready ? _compressed!.length : null;
    final int? estimatedCharge = ready ? _chargeFor(_compressed!.length) : null;
    final int savings = ready ? (originalSize - estimatedSize!) : 0;

    return AlertDialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusCard),
        side: BorderSide(color: t.border, width: t.borderWidth),
      ),
      title: Text(
        t.uppercaseLabels
            ? l10n.chatImageCompressionTitle.toUpperCase()
            : l10n.chatImageCompressionTitle,
        style: t.screenTitle.copyWith(fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chatImageCompressionOriginal(
              AppState.formatBytes(originalSize),
            ),
            style: t.dataMono.copyWith(color: t.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 4),
          // Real (not estimated) output size + charge, computed by compressing.
          Row(
            children: [
              if (!ready)
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.4,
                    valueColor: AlwaysStoppedAnimation<Color>(t.action),
                  ),
                )
              else
                Flexible(
                  child: Text(
                    savings > 0
                        ? l10n.chatImageCompressionEstimatedWithSaving(
                            AppState.formatBytes(estimatedSize!),
                            AppState.formatBytes(savings),
                          )
                        : l10n.chatImageCompressionEstimated(
                            AppState.formatBytes(estimatedSize!),
                          ),
                    style: t.dataMono.copyWith(
                      color: savings > 0 ? t.action : t.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              if (ready && _busy) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: 9,
                  height: 9,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.2,
                    valueColor: AlwaysStoppedAnimation<Color>(t.textTertiary),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ready
                ? l10n.chatImageCompressionCost(
                    AppState.formatBytes(estimatedCharge!),
                  )
                : l10n.chatImageCompressionCost('…'),
            style: t.dataMono.copyWith(color: t.textTertiary),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.chatImageCompressionExplanation,
            style: t.dataMono.copyWith(color: t.textTertiary, fontSize: 9),
          ),
          const SizedBox(height: 12),
          Slider(
            value: quality,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            activeColor: t.action,
            inactiveColor: t.budgetEmpty,
            label: quality == 1.0
                ? l10n.chatImageCompressionMaxQuality
                : '${(quality * 100).toInt()}%',
            onChanged: (val) {
              setState(() => quality = val);
              _scheduleRecompute();
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.chatImageCompressionLowSize, style: t.bodySecondary),
              Text(
                quality == 1.0
                    ? l10n.chatImageCompressionMaxQuality
                    : l10n.chatImageCompressionPercentQuality(
                        (quality * 100).toInt(),
                      ),
                style: t.body.copyWith(
                  color: t.action,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(l10n.chatImageCompressionHighSize, style: t.bodySecondary),
            ],
          ),
          Divider(color: t.border, height: 20),
          // Optional spoiler / hidden send (off by default — images show inline).
          // Disabled while wilting is on: the wilt gate is its own reveal.
          Row(
            children: [
              Icon(
                hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: ephemeral
                    ? t.textTertiary.withValues(alpha: 0.4)
                    : (hidden ? t.action : t.textTertiary),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.chatImageCompressionSendHidden,
                  style: t.body.copyWith(
                    fontSize: 12,
                    color: ephemeral ? t.textTertiary.withValues(alpha: 0.5) : null,
                  ),
                ),
              ),
              Switch(
                value: hidden && !ephemeral,
                activeThumbColor: t.action,
                onChanged: ephemeral
                    ? null
                    : (val) => setState(() => hidden = val),
              ),
            ],
          ),
          // Opt-in: let the recipient save this image to their gallery. Off by
          // default — images are view-only unless the sender allows a download.
          // Disabled while wilting is on (a wilting image can't be downloadable).
          Row(
            children: [
              Icon(
                allowSave
                    ? Icons.download_outlined
                    : Icons.file_download_off_outlined,
                color: ephemeral
                    ? t.textTertiary.withValues(alpha: 0.4)
                    : (allowSave ? t.action : t.textTertiary),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.chatImageCompressionAllowDownload,
                  style: t.body.copyWith(
                    fontSize: 12,
                    color: ephemeral ? t.textTertiary.withValues(alpha: 0.5) : null,
                  ),
                ),
              ),
              Switch(
                value: allowSave && !ephemeral,
                activeThumbColor: t.action,
                onChanged: ephemeral
                    ? null
                    : (val) => setState(() => allowSave = val),
              ),
            ],
          ),
          // Wilting (disappearing) image. Turning it on forces download + hidden
          // off (both are incompatible with a message that self-destructs).
          Row(
            children: [
              Icon(
                Icons.local_florist_outlined,
                color: ephemeral ? t.action : t.textTertiary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.chatImageCompressionWilting,
                  style: t.body.copyWith(fontSize: 12),
                ),
              ),
              Switch(
                value: ephemeral,
                activeThumbColor: t.action,
                onChanged: (val) => setState(() {
                  ephemeral = val;
                  if (val) {
                    allowSave = false;
                    hidden = false;
                  }
                }),
              ),
            ],
          ),
          if (ephemeral)
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: ttl,
                    min: 1,
                    max: 60,
                    divisions: 59,
                    activeColor: t.action,
                    inactiveColor: t.budgetEmpty,
                    label: '${ttl.round()}s',
                    onChanged: (val) => setState(() => ttl = val),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${ttl.round()}s',
                    textAlign: TextAlign.end,
                    style: t.dataMono.copyWith(
                      color: t.action,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
        ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(
            l10n.commonCancel,
            style: TextStyle(color: t.textSecondary),
          ),
        ),
        ElevatedButton(
          // Disabled until the first compression lands so we always return bytes.
          onPressed: ready ? _onSend : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: t.action,
            foregroundColor: t.onAction,
            disabledBackgroundColor: t.action.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
          ),
          child: Text(l10n.chatImageCompressionSendButton),
        ),
      ],
    );
  }
}
