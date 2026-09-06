import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/theme/wk.dart';
import 'pixel_art_attachment_sheet.dart';

/// The result returned from the unified content attachment sheet.
sealed class ContentAttachmentResult {
  const ContentAttachmentResult();
}

class PhotoAttachmentResult extends ContentAttachmentResult {
  final ImageSource source;
  const PhotoAttachmentResult(this.source);
}

class PixelArtAttachmentResult extends ContentAttachmentResult {
  final String hexString;
  const PixelArtAttachmentResult(this.hexString);
}

class VideoAttachmentResult extends ContentAttachmentResult {
  final ImageSource source;
  const VideoAttachmentResult(this.source);
}

enum _AttachmentCategory {
  photo,
  pixelArt,
  video,
}

/// Unified attachment sheet letting the user pick between Photos/Camera,
/// Pixel Art / Avatars (Draw or Template Library), or Video (Coming Soon).
Future<ContentAttachmentResult?> showContentAttachmentSheet(BuildContext context) async {
  final t = context.wk;
  final l10n = AppLocalizations.of(context)!;

  final category = await showModalBottomSheet<_AttachmentCategory>(
    context: context,
    backgroundColor: t.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
      side: BorderSide(color: t.border),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.uppercaseLabels
                      ? (l10n.chatAttachContentTitle ?? 'Attach to chat').toUpperCase()
                      : (l10n.chatAttachContentTitle ?? 'Attach to chat'),
                  style: t.screenTitle.copyWith(fontSize: 15),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: t.textSecondary),
                  onPressed: () => Navigator.pop(sheetCtx),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.action.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
              child: Icon(Icons.photo_library_outlined, color: t.action, size: 22),
            ),
            title: Text(
              l10n.chatAttachPhotos ?? 'Photos & Camera',
              style: t.body.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              l10n.chatAttachPhotosSubtitle ?? 'Take a picture or choose from gallery',
              style: t.bodySecondary.copyWith(fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: t.textTertiary, size: 18),
            onTap: () {
              Navigator.pop(sheetCtx, _AttachmentCategory.photo);
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.positive.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
              child: Icon(Icons.palette_outlined, color: t.positive, size: 22),
            ),
            title: Text(
              l10n.chatAttachPixelArt ?? 'Pixel Art & Avatars',
              style: t.body.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              l10n.chatAttachPixelArtSubtitle ?? 'Draw a pixel drawing or send from saved templates',
              style: t.bodySecondary.copyWith(fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: t.textTertiary, size: 18),
            onTap: () {
              Navigator.pop(sheetCtx, _AttachmentCategory.pixelArt);
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
              child: Icon(Icons.videocam_outlined, color: t.warning, size: 22),
            ),
            title: Text(
              l10n.chatAttachVideo ?? 'Video',
              style: t.body.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              l10n.chatAttachVideoSubtitleEnabled ?? 'Record up to 15s or pick from gallery',
              style: t.bodySecondary.copyWith(fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: t.textTertiary, size: 18),
            onTap: () {
              Navigator.pop(sheetCtx, _AttachmentCategory.video);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );

  if (category == null || !context.mounted) return null;

  if (category == _AttachmentCategory.photo) {
    final src = await _showPhotoSourceSubSheet(context);
    if (src != null) {
      return PhotoAttachmentResult(src);
    }
  } else if (category == _AttachmentCategory.pixelArt) {
    final hex = await showPixelArtAttachmentSheet(context);
    if (hex != null && hex.isNotEmpty) {
      return PixelArtAttachmentResult(hex);
    }
  } else if (category == _AttachmentCategory.video) {
    final src = await _showVideoSourceSubSheet(context);
    if (src != null) {
      return VideoAttachmentResult(src);
    }
  }

  return null;
}

Future<ImageSource?> _showPhotoSourceSubSheet(BuildContext context) {
  final t = context.wk;
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: t.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
      side: BorderSide(color: t.border),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t.uppercaseLabels
                    ? l10n.chatImageSourceTitle.toUpperCase()
                    : l10n.chatImageSourceTitle,
                style: t.screenTitle.copyWith(fontSize: 15),
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.photo_camera_outlined, color: t.action),
            title: Text(l10n.chatImageSourceCamera, style: t.body),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: Icon(Icons.photo_library_outlined, color: t.action),
            title: Text(l10n.chatImageSourceGallery, style: t.body),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<ImageSource?> _showVideoSourceSubSheet(BuildContext context) {
  final t = context.wk;
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: t.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
      side: BorderSide(color: t.border),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t.uppercaseLabels
                    ? (l10n.chatVideoSelectSourceTitle ?? 'Send Video').toUpperCase()
                    : (l10n.chatVideoSelectSourceTitle ?? 'Send Video'),
                style: t.screenTitle.copyWith(fontSize: 15),
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.videocam_outlined, color: t.warning),
            title: Text(l10n.chatVideoRecordCamera ?? 'Record Video (Camera)', style: t.body),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: Icon(Icons.video_library_outlined, color: t.warning),
            title: Text(l10n.chatVideoPickGallery ?? 'Choose Video from Gallery', style: t.body),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
