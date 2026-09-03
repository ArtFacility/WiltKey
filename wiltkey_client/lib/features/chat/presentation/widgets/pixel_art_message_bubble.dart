import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:wiltkey_client/core/custom_emoji.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/persistence.dart';
import 'package:wiltkey_client/core/pixel_art_avatar.dart';
import 'package:wiltkey_client/core/pixel_palette.dart';
import 'package:wiltkey_client/core/state.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/theme/wk.dart';

/// Rasterizes a 10x10 pixel art string into PNG image bytes.
Future<Uint8List> rasterizePixelArtPng(String hexString, {int scale = 20}) async {
  final indices = PixelGrid.parseOrBlank(hexString);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = PixelGrid.dim * scale.toDouble();
  final paint = Paint()..style = PaintingStyle.fill;

  for (int y = 0; y < PixelGrid.dim; y++) {
    for (int x = 0; x < PixelGrid.dim; x++) {
      final idx = indices[y * PixelGrid.dim + x];
      paint.color = WkPalette.colorAt(idx);
      canvas.drawRect(
        Rect.fromLTWH(
          x * scale.toDouble(),
          y * scale.toDouble(),
          scale.toDouble(),
          scale.toDouble(),
        ),
        paint,
      );
    }
  }
  final picture = recorder.endRecording();
  final img = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// Interactive pixel art message widget that renders in chat bubbles and provides
/// one-tap actions to Apply as Avatar, Save to Templates, Save as Emoji, or Export PNG.
class PixelArtMessageCard extends StatelessWidget {
  final String hexString;
  final bool isSentByMe;
  final VoidCallback? onLongPress;

  const PixelArtMessageCard({
    super.key,
    required this.hexString,
    required this.isSentByMe,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;

    return GestureDetector(
      onTap: () => showPixelArtActionSheet(context, hexString),
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: t.bg.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(t.radiusControl),
          border: Border.all(
            color: isSentByMe ? t.bubbleMeBorder : t.border,
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(t.radiusControl),
              child: PixelArtAvatar(
                hexString: hexString,
                size: 130,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.palette_outlined, size: 12, color: t.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Pixel Art',
                  style: t.dataMono.copyWith(fontSize: 10, color: t.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Action sheet presented when tapping a received or sent pixel art card.
Future<void> showPixelArtActionSheet(BuildContext context, String hexString) async {
  final t = context.wk;
  final l10n = AppLocalizations.of(context)!;
  final appState = AppState();

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: t.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
      side: BorderSide(color: t.border),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.uppercaseLabels
                      ? (l10n.chatPixelArtActionTitle ?? 'Pixel Art Options').toUpperCase()
                      : (l10n.chatPixelArtActionTitle ?? 'Pixel Art Options'),
                  style: t.screenTitle.copyWith(fontSize: 16),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: t.textSecondary),
                  onPressed: () => Navigator.pop(sheetCtx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(color: t.border),
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
                child: PixelArtAvatar(hexString: hexString, size: 80),
              ),
            ),
            const SizedBox(height: 16),

            // Action 1: Apply as My Avatar
            ListTile(
              leading: Icon(Icons.account_circle_outlined, color: t.action),
              title: Text(
                l10n.chatPixelArtActionApplyAvatar ?? 'Apply as My Profile Avatar',
                style: t.body,
              ),
              onTap: () async {
                appState.updateProfile(
                  name: appState.deviceName,
                  nick: appState.shortNick,
                  imageB64: hexString,
                );
                await appState.broadcastProfileUpdate();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: t.surface,
                      content: Text(
                        l10n.chatPixelArtActionAppliedAvatarSuccess ??
                            'Profile avatar updated and synced',
                        style: t.body.copyWith(color: t.action),
                      ),
                    ),
                  );
                }
              },
            ),

            // Action 2: Save to Templates Library
            ListTile(
              leading: Icon(Icons.bookmarks_outlined, color: t.positive),
              title: Text(
                l10n.chatPixelArtActionSaveTemplate ?? 'Save to Avatar Templates',
                style: t.body,
              ),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await WiltkeyPersistence().saveAvatarTemplate(hexString);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: t.surface,
                      content: Text(
                        l10n.chatPixelArtActionSavedTemplateSuccess ??
                            'Saved to Avatar Templates library',
                        style: t.body.copyWith(color: t.positive),
                      ),
                    ),
                  );
                }
              },
            ),

            // Action 3: Save as Custom Emoji
            ListTile(
              leading: Icon(Icons.add_reaction_outlined, color: t.warning),
              title: Text(
                l10n.chatPixelArtActionSaveEmoji ?? 'Save as Custom Emoji',
                style: t.body,
              ),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final name = await _promptEmojiName(context);
                if (name != null && name.trim().isNotEmpty && context.mounted) {
                  final active = appState.activeContact;
                  if (active != null) {
                    final cleanName = name.trim().replaceAll(':', '');
                    final pngBytes = await rasterizePixelArtPng(hexString, scale: 6);
                    final emoji = CustomEmoji(
                      name: cleanName,
                      imageB64: base64Encode(pngBytes),
                      createdAtMs: DateTime.now().millisecondsSinceEpoch,
                    );
                    await appState.defineEmoji(active, emoji);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: t.surface,
                          content: Text(
                            'Saved as :$cleanName: in custom emojis',
                            style: t.body.copyWith(color: t.warning),
                          ),
                        ),
                      );
                    }
                  }
                }
              },
            ),

            // Action 4: Export PNG to Photos Gallery
            ListTile(
              leading: Icon(Icons.file_download_outlined, color: t.textPrimary),
              title: Text(
                l10n.chatPixelArtActionExportPng ?? 'Export PNG to Photos',
                style: t.body,
              ),
              onTap: () async {
                Navigator.pop(sheetCtx);
                try {
                  final pngBytes = await rasterizePixelArtPng(hexString, scale: 20);
                  await Gal.putImageBytes(pngBytes);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: t.surface,
                        content: Text(
                          l10n.chatPixelArtActionExportedPngSuccess ??
                              'Saved PNG image to photos',
                          style: t.body,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: t.surface,
                        content: Text(
                          'Failed to export PNG: $e',
                          style: t.bodySecondary.copyWith(color: t.danger),
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> _promptEmojiName(BuildContext context) async {
  final t = context.wk;
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusCard),
        side: BorderSide(color: t.border),
      ),
      title: Text('Custom Emoji Shortcode', style: t.screenTitle.copyWith(fontSize: 15)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: t.body,
        decoration: InputDecoration(
          hintText: 'e.g. pepe, fire, cool',
          hintStyle: t.bodySecondary,
          prefixText: ':',
          suffixText: ':',
          prefixStyle: t.dataMono.copyWith(color: t.action),
          suffixStyle: t.dataMono.copyWith(color: t.action),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('CANCEL', style: t.bodySecondary),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: t.action, foregroundColor: t.onAction),
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text('SAVE', style: t.body.copyWith(fontWeight: FontWeight.bold, color: t.onAction)),
        ),
      ],
    ),
  );
}
