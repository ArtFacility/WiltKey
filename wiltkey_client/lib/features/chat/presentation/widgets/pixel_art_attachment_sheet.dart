import 'package:flutter/material.dart';
import 'package:wiltkey_client/core/persistence.dart';
import 'package:wiltkey_client/core/pixel_art_avatar.dart';
import 'package:wiltkey_client/core/pixel_art_editor.dart';
import 'package:wiltkey_client/core/pixel_palette.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/theme/wk.dart';

enum _PixelArtAction { drawNew }

/// Modal bottom sheet for choosing or drawing Pixel Art to send in chat.
Future<String?> showPixelArtAttachmentSheet(BuildContext context) async {
  final t = context.wk;
  final l10n = AppLocalizations.of(context)!;
  final persistence = WiltkeyPersistence();
  final templates = await persistence.loadAvatarTemplates();

  if (!context.mounted) return null;

  final res = await showModalBottomSheet<dynamic>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
      side: BorderSide(color: t.border),
    ),
    builder: (sheetCtx) {
      String? selectedHex;
      return StatefulBuilder(
        builder: (ctx, setState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.uppercaseLabels
                            ? (l10n.chatAttachPixelArt ?? 'Pixel Art & Avatars').toUpperCase()
                            : (l10n.chatAttachPixelArt ?? 'Pixel Art & Avatars'),
                        style: t.screenTitle.copyWith(fontSize: 16),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 20, color: t.textSecondary),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Option 1: Draw New
                  InkWell(
                    onTap: () {
                      Navigator.pop(sheetCtx, _PixelArtAction.drawNew);
                    },
                    borderRadius: BorderRadius.circular(t.radiusControl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: t.action.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(t.radiusControl),
                        color: t.action.withValues(alpha: 0.08),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.draw_outlined, color: t.action, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.chatPixelArtDrawNew ?? 'Draw New Pixel Art',
                                  style: t.body.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: t.action,
                                  ),
                                ),
                                Text(
                                  'Create a new 16x16 / 10x10 drawing',
                                  style: t.bodySecondary.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: t.action, size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    t.uppercaseLabels
                        ? (l10n.chatPixelArtTemplates ?? 'Saved Avatar Templates').toUpperCase()
                        : (l10n.chatPixelArtTemplates ?? 'Saved Avatar Templates'),
                    style: t.sectionLabel,
                  ),
                  const SizedBox(height: 8),

                  if (templates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          l10n.chatPixelArtNoTemplates ?? 'No saved avatar templates yet',
                          style: t.bodySecondary.copyWith(fontSize: 13),
                        ),
                      ),
                    )
                  else ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: GridView.builder(
                        shrinkWrap: true,
                        itemCount: templates.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.0,
                        ),
                        itemBuilder: (gridCtx, i) {
                          final tmpl = templates[i];
                          final isSelected = selectedHex == tmpl;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedHex = isSelected ? null : tmpl;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(t.radiusControl),
                                border: Border.all(
                                  color: isSelected ? t.action : t.border,
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                                color: isSelected
                                    ? t.action.withValues(alpha: 0.15)
                                    : t.surface,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Center(
                                child: PixelArtAvatar(
                                  hexString: tmpl,
                                  size: 38,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (selectedHex != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: t.action,
                            foregroundColor: t.onAction,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(t.radiusControl),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(sheetCtx, selectedHex);
                          },
                          child: Text(
                            t.uppercaseLabels
                                ? (l10n.chatPixelArtSend ?? 'Send to Chat').toUpperCase()
                                : (l10n.chatPixelArtSend ?? 'Send to Chat'),
                            style: t.body.copyWith(
                              fontWeight: FontWeight.bold,
                              color: t.onAction,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (res == null || !context.mounted) return null;

  if (res == _PixelArtAction.drawNew) {
    return await showPixelArtEditor(
      context,
      initialHex: PixelGrid.blank,
      title: l10n.chatPixelArtDrawNew ?? 'Draw Pixel Art',
    );
  }

  if (res is String) {
    return res;
  }

  return null;
}
