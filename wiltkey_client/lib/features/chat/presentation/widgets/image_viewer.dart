import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gal/gal.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/theme/wk.dart';
import '../../../../core/theme/wiltkey_tokens.dart';

/// Full-screen, pinch-to-zoom / pan image viewer shared by 1-on-1 and group
/// chats (so the popup isn't duplicated per screen). Tap an inline image to
/// push this; it shows the decoded bytes at full size.
///
/// The Download button is shown ONLY when [allowSave] is true — i.e. the sender
/// opted the image in at send time. On download the user picks an output format
/// (WebP is the stored original; JPEG/PNG are transcoded) and the result is
/// written to the system gallery via `gal`.
class ImageViewerScreen extends StatelessWidget {
  final Uint8List imageBytes;
  final bool allowSave;

  const ImageViewerScreen({
    super.key,
    required this.imageBytes,
    required this.allowSave,
  });

  /// Push the viewer as a full-screen route.
  static Future<void> open(
    BuildContext context, {
    required Uint8List imageBytes,
    required bool allowSave,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            ImageViewerScreen(imageBytes: imageBytes, allowSave: allowSave),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Zoom / pan surface. clipBehavior none lets the image overflow while
          // panning; the black scaffold is the backdrop.
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 6.0,
              child: Center(
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.broken_image,
                    color: t.danger,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          // Close button (top-left, inside the safe area).
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _CircleButton(
                  icon: Icons.close,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          // Download button (bottom-right) — only when the sender allowed saving.
          if (allowSave)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FloatingActionButton.extended(
                    backgroundColor: t.action,
                    foregroundColor: t.onAction,
                    onPressed: () => _download(context),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(AppLocalizations.of(context)!.chatImageDownload),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final t = context.wk;

    final format = await _pickFormat(context);
    if (format == null) return;

    Uint8List outBytes;
    try {
      outBytes = await _transcode(imageBytes, format);
    } catch (_) {
      outBytes = imageBytes; // fall back to the original (WebP) bytes
    }

    final name = 'wiltkey_${DateTime.now().millisecondsSinceEpoch}';
    try {
      // gal handles the platform permission/scoped-storage details; requestAccess
      // is a no-op on Android 10+ (MediaStore needs no permission there).
      if (!await Gal.requestAccess()) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: t.surface,
            content: Text(
              l10n.chatImageSaveFailed,
              style: t.bodySecondary.copyWith(color: t.danger),
            ),
          ),
        );
        return;
      }
      await Gal.putImageBytes(outBytes, name: name);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: t.surface,
          content: Text(
            l10n.chatImageSavedToGallery,
            style: t.bodySecondary.copyWith(color: t.action),
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: t.surface,
          content: Text(
            l10n.chatImageSaveFailed,
            style: t.bodySecondary.copyWith(color: t.danger),
          ),
        ),
      );
    }
  }

  /// Bottom-sheet format chooser. Many users dislike WebP, so JPEG/PNG are
  /// offered alongside the original.
  Future<_DownloadFormat?> _pickFormat(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    return showModalBottomSheet<_DownloadFormat>(
      context: context,
      backgroundColor: t.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t.uppercaseLabels
                      ? l10n.chatImageSaveAs.toUpperCase()
                      : l10n.chatImageSaveAs,
                  style: t.screenTitle.copyWith(fontSize: 15),
                ),
              ),
            ),
            _formatTile(ctx, t, 'JPEG', '.jpg', _DownloadFormat.jpeg),
            _formatTile(ctx, t, 'PNG', '.png', _DownloadFormat.png),
            _formatTile(ctx, t, 'WebP', '.webp', _DownloadFormat.webp),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _formatTile(
    BuildContext ctx,
    WiltkeyTokens t,
    String label,
    String ext,
    _DownloadFormat fmt,
  ) {
    return ListTile(
      leading: Icon(Icons.image_outlined, color: t.action),
      title: Text(label, style: t.body),
      trailing: Text(ext, style: t.dataMono.copyWith(color: t.textTertiary)),
      onTap: () => Navigator.of(ctx).pop(fmt),
    );
  }

  /// Transcode the stored WebP bytes to the requested format. WebP returns the
  /// original bytes untouched (no re-encode). A generous 4000px cap means sent
  /// images (already ≤2000px) are never downscaled here.
  static Future<Uint8List> _transcode(
    Uint8List src,
    _DownloadFormat fmt,
  ) async {
    if (fmt == _DownloadFormat.webp) return src;
    final out = await FlutterImageCompress.compressWithList(
      src,
      format: fmt == _DownloadFormat.png
          ? CompressFormat.png
          : CompressFormat.jpeg,
      minWidth: 4000,
      minHeight: 4000,
      quality: 95,
    );
    return Uint8List.fromList(out);
  }
}

enum _DownloadFormat { jpeg, png, webp }

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
