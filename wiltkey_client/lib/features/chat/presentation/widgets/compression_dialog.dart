import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/state.dart';
import '../../../../core/theme/wk.dart';

/// Result of the compression dialog: the chosen quality (0.1-1.0) and whether
/// the image should be sent hidden (tap-to-reveal spoiler).
class CompressionResult {
  final double quality;
  final bool hidden;
  const CompressionResult({required this.quality, required this.hidden});
}

class CompressionDialog extends StatefulWidget {
  final int originalSizeBytes;

  const CompressionDialog({super.key, required this.originalSizeBytes});

  static Future<CompressionResult?> show(
    BuildContext context,
    int originalSizeBytes,
  ) {
    return showDialog<CompressionResult>(
      context: context,
      builder: (context) =>
          CompressionDialog(originalSizeBytes: originalSizeBytes),
    );
  }

  @override
  State<CompressionDialog> createState() => _CompressionDialogState();
}

class _CompressionDialogState extends State<CompressionDialog> {
  double quality = 0.5;
  bool hidden = false;

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    // Estimate compressed size (rough heuristic: quality * originalSize)
    final int estimatedSize = quality == 1.0
        ? widget.originalSizeBytes
        : (widget.originalSizeBytes * quality * 0.7).toInt();
    // Base64 inflates by ~33%, plus 73 bytes header overhead
    final int estimatedCharge = ((estimatedSize * 4) / 3).toInt() + 73;
    final int savings = widget.originalSizeBytes - estimatedSize;

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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chatImageCompressionOriginal(
              AppState.formatBytes(widget.originalSizeBytes),
            ),
            style: t.dataMono.copyWith(color: t.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            savings > 0
                ? l10n.chatImageCompressionEstimatedWithSaving(
                    AppState.formatBytes(estimatedSize),
                    AppState.formatBytes(savings),
                  )
                : l10n.chatImageCompressionEstimated(
                    AppState.formatBytes(estimatedSize),
                  ),
            style: t.dataMono.copyWith(
              color: savings > 0 ? t.action : t.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.chatImageCompressionCost(
              AppState.formatBytes(estimatedCharge),
            ),
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
              setState(() {
                quality = val;
              });
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
          Row(
            children: [
              Icon(
                hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: hidden ? t.action : t.textTertiary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.chatImageCompressionSendHidden,
                  style: t.body.copyWith(fontSize: 12),
                ),
              ),
              Switch(
                value: hidden,
                activeThumbColor: t.action,
                onChanged: (val) => setState(() => hidden = val),
              ),
            ],
          ),
        ],
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
          onPressed: () => Navigator.pop(
            context,
            CompressionResult(quality: quality, hidden: hidden),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: t.action,
            foregroundColor: t.onAction,
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
