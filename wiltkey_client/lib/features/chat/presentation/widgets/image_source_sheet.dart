import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/theme/wk.dart';

/// Bottom sheet letting the user pick where an image comes from — the in-app
/// camera or the gallery. Shared by 1-on-1 and group chats so the chooser isn't
/// duplicated. Returns the chosen [ImageSource], or null if dismissed.
Future<ImageSource?> showImageSourceSheet(BuildContext context) {
  final t = context.wk;
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<ImageSource>(
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
                    ? l10n.chatImageSourceTitle.toUpperCase()
                    : l10n.chatImageSourceTitle,
                style: t.screenTitle.copyWith(fontSize: 15),
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.photo_camera_outlined, color: t.action),
            title: Text(l10n.chatImageSourceCamera, style: t.body),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: Icon(Icons.photo_library_outlined, color: t.action),
            title: Text(l10n.chatImageSourceGallery, style: t.body),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
