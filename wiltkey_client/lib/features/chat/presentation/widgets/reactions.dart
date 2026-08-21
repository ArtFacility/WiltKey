import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/state.dart';
import '../../../../core/models.dart';
import '../../../../core/custom_emoji.dart';
import '../../../../core/theme/wk.dart';
import '../../../../core/theme/wiltkey_tokens.dart';
import 'emoji_picker_panel.dart';

/// Quick unicode reactions offered first in the picker, before the chat's custom
/// emoji pool. 🥀 is on-brand (WiltKey wilts).
const List<String> kQuickReactions = [
  '👍',
  '❤️',
  '😂',
  '😮',
  '😢',
  '🔥',
  '🎉',
  '🙏',
  '💀',
  '😭',
  '🥀',
  '❌',
  '✅',
];

final RegExp _customTokenRe = RegExp(r'^:([a-z0-9_]{2,32}):$');

/// Renders a reaction token sized to [size], normalising unicode glyphs and
/// custom-emoji images to the same visual box (unicode glyphs otherwise render
/// noticeably larger than the images beside them). A custom `:name:` becomes its
/// image when it resolves in the live pool; a tombstoned / unknown custom token
/// falls back to a neutral placeholder so the count survives without a crash.
Widget reactionTokenGlyph(
  String token,
  Map<String, CustomEmoji> emojiMap,
  double size,
) {
  final m = _customTokenRe.firstMatch(token);
  if (m != null) {
    final emoji = emojiMap[m.group(1)];
    if (emoji != null) {
      return Image.memory(
        emoji.bytes,
        width: size,
        height: size,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) =>
            Icon(Icons.broken_image_outlined, size: size),
      );
    }
    return Icon(Icons.help_outline, size: size); // deleted/unknown custom emoji
  }
  // Unicode emoji glyphs render larger than their nominal font size, so shrink
  // to ~0.82x to match the custom-emoji images they sit next to.
  return SizedBox(
    height: size,
    child: Center(
      child: Text(token, style: TextStyle(fontSize: size * 0.82, height: 1.0)),
    ),
  );
}

/// A wrapping row of reaction chips shown under a message bubble. Tap a chip to
/// toggle your own reaction; long-press to see who reacted. Scales with the
/// chat's text-size setting so it grows alongside the bubbles.
class ReactionsRow extends StatelessWidget {
  final ChatMessage message;
  final Contact contact;
  final AppState appState;
  final Map<String, CustomEmoji> emojiMap;
  final bool isMe;

  const ReactionsRow({
    super.key,
    required this.message,
    required this.contact,
    required this.appState,
    required this.emojiMap,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final e in message.reactions.entries)
        if (e.value.isNotEmpty) e,
    ];
    if (entries.isEmpty) return const SizedBox.shrink();
    final t = context.wk;
    final scale = appState.chatTextScale;
    return Padding(
      padding: EdgeInsets.only(
        top: 3,
        bottom: 2,
        left: isMe ? 0 : 2,
        right: isMe ? 2 : 0,
      ),
      child: Wrap(
        alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final e in entries) _chip(context, t, scale, e.key, e.value),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    WiltkeyTokens t,
    double scale,
    String token,
    Set<String> reactors,
  ) {
    final mine = reactors.contains(appState.userId);
    final count = reactors.length;
    return GestureDetector(
      onTap: () => appState.toggleReaction(contact, message, token),
      onLongPress: () => _showWhoReacted(context, t, token, reactors),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 6 * scale,
          vertical: 2 * scale,
        ),
        decoration: BoxDecoration(
          color: mine ? t.action.withValues(alpha: 0.18) : t.surface,
          border: Border.all(
            color: mine ? t.action : t.border,
            width: mine ? 1.2 : 1,
          ),
          borderRadius: BorderRadius.circular(t.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            reactionTokenGlyph(token, emojiMap, 15 * scale),
            if (count > 1) ...[
              SizedBox(width: 3 * scale),
              Text(
                '$count',
                style: t.dataMono.copyWith(
                  fontSize: 10 * scale,
                  color: mine ? t.action : t.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _reactorName(String id) {
    if (id == appState.userId) return 'You';
    if (contact.isGroup) {
      final members = appState.groupMembersMetadata[contact.id] ?? [];
      for (final m in members) {
        if (m['keyHash'] == id) {
          final n = (m['name'] as String?)?.toString().trim();
          return (n != null && n.isNotEmpty) ? n : 'Member';
        }
      }
      return 'Member';
    }
    return contact.name;
  }

  void _showWhoReacted(
    BuildContext context,
    WiltkeyTokens t,
    String token,
    Set<String> reactors,
  ) {
    final names = [for (final id in reactors) _reactorName(id)];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.border),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            reactionTokenGlyph(token, emojiMap, 22),
            const SizedBox(width: 8),
            Text(
              '${reactors.length}',
              style: t.screenTitle.copyWith(fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final n in names)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(n, style: t.body.copyWith(color: t.textPrimary)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: t.body.copyWith(color: t.action)),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet reaction picker: quick unicode reactions, the chat's custom emoji
/// pool, and a "+" that opens the full curated emoji set. Also shows Edit/Delete
/// options for messages authored by the user.
Future<void> showReactionPicker(
  BuildContext context, {
  required AppState appState,
  required Contact contact,
  required ChatMessage message,
  required Map<String, CustomEmoji> emojiMap,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) {
  final t = context.wk;
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet(
    context: context,
    backgroundColor: t.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
      side: BorderSide(color: t.border),
    ),
    builder: (ctx) {
      void pick(String token) {
        appState.toggleReaction(contact, message, token);
        Navigator.pop(ctx);
      }

      Future<void> pickMore() async {
        final picked = await _showFullEmojiSheet(ctx, t);
        if (picked != null) pick(picked);
      }

      final customTokens = [for (final name in emojiMap.keys) ':$name:'];
      final bool canEdit = message.isSentByMe &&
          !message.wilted &&
          !message.isDeleted &&
          message.contentType == 'text' &&
          onEdit != null;
      final bool canDelete = message.isSentByMe &&
          !message.wilted &&
          !message.isDeleted &&
          onDelete != null;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final e in kQuickReactions)
                    _pickButton(
                      t,
                      reactionTokenGlyph(e, emojiMap, 26),
                      () => pick(e),
                    ),
                  // "+" opens the full curated emoji set.
                  _pickButton(
                    t,
                    Icon(Icons.add, color: t.action, size: 26),
                    pickMore,
                  ),
                ],
              ),
              if (customTokens.isNotEmpty) ...[
                const SizedBox(height: 14),
                Divider(color: t.border, height: 1),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final token in customTokens)
                      _pickButton(
                        t,
                        reactionTokenGlyph(token, emojiMap, 26),
                        () => pick(token),
                      ),
                  ],
                ),
              ],
              if (canEdit || canDelete) ...[
                const SizedBox(height: 14),
                Divider(color: t.border, height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (canEdit)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onEdit();
                          },
                          icon: Icon(Icons.edit_outlined, size: 18, color: t.action),
                          label: Text(
                            l10n?.chatActionEdit ?? 'Edit',
                            style: t.body.copyWith(
                              color: t.action,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: t.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(t.radiusControl),
                            ),
                          ),
                        ),
                      ),
                    if (canEdit && canDelete) const SizedBox(width: 10),
                    if (canDelete)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onDelete();
                          },
                          icon: Icon(Icons.delete_outline, size: 18, color: t.danger),
                          label: Text(
                            l10n?.chatActionDelete ?? 'Delete',
                            style: t.body.copyWith(
                              color: t.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: t.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(t.radiusControl),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// A scrollable grid of the full curated emoji set; returns the tapped emoji.
Future<String?> _showFullEmojiSheet(BuildContext context, WiltkeyTokens t) {
  final all = [
    for (final cat in EmojiPickerPanel.categories) ...cat,
  ];
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: t.surface,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
      side: BorderSide(color: t.border),
    ),
    builder: (ctx) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.5,
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: t.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 46,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                  itemCount: all.length,
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => Navigator.pop(ctx, all[i]),
                    child: Center(
                      child: Text(
                        all[i],
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _pickButton(WiltkeyTokens t, Widget glyph, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.bg,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: glyph,
    ),
  );
}
