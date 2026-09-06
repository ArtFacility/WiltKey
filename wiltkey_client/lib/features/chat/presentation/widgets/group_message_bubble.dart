import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/cosmetics/avatar_border_controller.dart';
import '../../../../core/custom_emoji.dart';
import '../../../../core/models.dart';
import '../../../../core/pixel_art_avatar.dart';
import '../../../../core/state.dart';
import '../../../../core/theme/wk.dart';
import '../../../../core/theme/wiltkey_tokens.dart';
import 'chat_image_thumbnail.dart';
import 'chat_markdown.dart';
import 'download_bubble.dart';
import 'image_viewer.dart';
import 'mention_autocomplete_bar.dart';
import 'reactions.dart';
import 'reply_preview.dart';
import 'voice_message_player.dart';
import 'wilt_widgets.dart';
import 'pixel_art_message_bubble.dart';
import 'video_message_bubble.dart';

/// A complete message bubble for group chats.
///
/// Handles sender attribution, avatar borders, custom emojis, markdown rich text,
/// images, voice notes, stickers, reactions, replies, and wilting states.
class GroupMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String displayText;
  final Contact group;
  final AppState appState;
  final bool isMe;
  final bool isFirstInBatch;
  final Map<String, CustomEmoji> emojiMap;
  final VoidCallback? onQuoteTap;
  final VoidCallback? onFailedTap;
  final void Function(String keyHash, String name)? onMemberTap;
  final Set<String> revealedImageIds;
  final void Function(String messageId)? onRevealImage;
  final void Function(ChatMessage message)? onEdit;
  final void Function(ChatMessage message)? onDelete;

  const GroupMessageBubble({
    super.key,
    required this.message,
    required this.displayText,
    required this.group,
    required this.appState,
    required this.isMe,
    required this.isFirstInBatch,
    this.emojiMap = const {},
    this.onQuoteTap,
    this.onFailedTap,
    this.onMemberTap,
    this.revealedImageIds = const {},
    this.onRevealImage,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;

    if (message.isSystem) {
      return _buildSystemPill(t, l10n);
    }

    final String? sticker = stickerPayload(displayText);
    final bool isSticker = sticker != null;
    final Color metaColor = isSticker
        ? t.textTertiary
        : (isMe ? t.bubbleMeText.withValues(alpha: 0.6) : t.textTertiary);

    final String senderKeyHash = message.senderId;
    final String senderName = _resolveSenderName(l10n);
    final String? cachedImage =
        appState.groupProfilesCache[group.id]?[senderKeyHash]?['profile_image'];
    final String avatarHex = isMe
        ? (appState.profileImageB64.isNotEmpty
            ? appState.profileImageB64
            : PixelArtAvatar.generateIdenticon(appState.userId))
        : (cachedImage != null && cachedImage.isNotEmpty
            ? cachedImage
            : PixelArtAvatar.generateIdenticon(senderKeyHash));
    final String? avatarBorderId = isMe
        ? AvatarBorderController.instance.borderId
        : appState.groupProfilesCache[group.id]?[senderKeyHash]?['avatar_border'];

    const double tail = 6;
    final double batchGap = isFirstInBatch ? 12 : 4;
    final bool isMentioned = !isMe &&
        appState.effectiveShortNick.isNotEmpty &&
        RegExp(
          r'@' + RegExp.escape(appState.effectiveShortNick) + r'\b',
          caseSensitive: false,
        ).hasMatch(displayText);

    final Widget bubble = Container(
      padding: isSticker
          ? const EdgeInsets.symmetric(horizontal: 2, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: isSticker
          ? const BoxDecoration()
          : BoxDecoration(
              color: isMe
                  ? t.bubbleMe
                  : (isMentioned
                      ? t.action.withValues(alpha: 0.15)
                      : t.bubbleThem),
              border: Border.all(
                color: message.isFailed
                    ? t.warning
                    : (isMentioned
                        ? t.action.withValues(alpha: 0.85)
                        : (isMe ? t.bubbleMeBorder : t.bubbleThemBorder)),
                width: message.isFailed
                    ? 1.5
                    : (isMentioned ? 1.5 : t.borderWidth),
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(t.radiusCard),
                topRight: Radius.circular(t.radiusCard),
                bottomLeft: isMe
                    ? Radius.circular(t.radiusCard)
                    : const Radius.circular(tail),
                bottomRight: isMe
                    ? const Radius.circular(tail)
                    : Radius.circular(t.radiusCard),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe && !isSticker) ...[
            GestureDetector(
              onTap: onMemberTap != null
                  ? () => onMemberTap!(senderKeyHash, senderName)
                  : null,
              child: Text(
                senderName,
                style: t.badgeLabel.copyWith(
                  color: t.identity,
                  fontWeight: FontWeight.bold,
                  fontSize: 10.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          buildReplyQuoteFor(
                context,
                appState,
                group,
                message,
                onTap: onQuoteTap,
              ) ??
              const SizedBox.shrink(),
          _buildContent(context, t, l10n),
          const SizedBox(height: 4),
          _buildMetaRow(t, l10n, metaColor),
        ],
      ),
    );

    final Widget shownBubble = message.isPending
        ? Opacity(opacity: 0.6, child: bubble)
        : bubble;

    final Widget bubbleWidget = GestureDetector(
      onTap: (message.isFailed && onFailedTap != null) ? onFailedTap : null,
      onLongPress: message.isPending
          ? null
          : () {
              FocusManager.instance.primaryFocus?.unfocus();
              showReactionPicker(
                context,
                appState: appState,
                contact: group,
                message: message,
                emojiMap: emojiMap,
                onEdit: onEdit != null ? () => onEdit!(message) : null,
                onDelete: onDelete != null ? () => onDelete!(message) : null,
              );
            },
      child: shownBubble,
    );

    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) ...[
          isFirstInBatch
              ? GestureDetector(
                  onTap: onMemberTap != null
                      ? () => onMemberTap!(senderKeyHash, senderName)
                      : null,
                  child: PixelArtAvatar(
                    hexString: avatarHex,
                    size: 28,
                    borderId: avatarBorderId,
                  ),
                )
              : const SizedBox(width: 28),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            heightFactor: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                bubbleWidget,
                ReactionsRow(
                  message: message,
                  contact: group,
                  appState: appState,
                  emojiMap: emojiMap,
                  isMe: isMe,
                ),
                SizedBox(height: batchGap),
              ],
            ),
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 8),
          isFirstInBatch
              ? PixelArtAvatar(
                  hexString: avatarHex,
                  size: 28,
                  borderId: avatarBorderId,
                )
              : const SizedBox(width: 28),
        ],
      ],
    );
  }

  String _resolveSenderName(AppLocalizations l10n) {
    final String senderKeyHash = message.senderId;
    final String? cachedName =
        appState.groupProfilesCache[group.id]?[senderKeyHash]?['name'];
    if (cachedName != null && cachedName.isNotEmpty) return cachedName;

    for (final c in appState.contacts) {
      if (c.keyHash == senderKeyHash) return c.name;
    }
    if (senderKeyHash.length > 8) {
      return 'Member ${senderKeyHash.substring(0, 6)}';
    }
    return l10n.groupMember;
  }

  Widget _buildSystemPill(WiltkeyTokens t, AppLocalizations l10n) {
    String systemText = displayText;
    if (displayText == 'Connected. Chat session secure.') {
      systemText = l10n.chatSystemConnected;
    } else if (displayText.startsWith('Joined group "') &&
        displayText.endsWith('". Connections secure.')) {
      final groupName = displayText.substring(
        'Joined group "'.length,
        displayText.length - '". Connections secure.'.length,
      );
      systemText = l10n.chatSystemJoinedGroup(groupName);
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: t.action.withValues(alpha: 0.07),
          border: Border.all(
            color: t.action.withValues(alpha: 0.25),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(t.radiusPill),
        ),
        child: Text(
          t.uppercaseLabels ? systemText.toUpperCase() : systemText,
          style: t.dataMono.copyWith(color: t.action, letterSpacing: 0.6),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WiltkeyTokens t,
    AppLocalizations l10n,
  ) {
    // Deleted messages render as a tombstone line.
    if (message.isDeleted) {
      return Text(
        l10n.chatMessageDeleted,
        style: t.bodySecondary.copyWith(
          fontStyle: FontStyle.italic,
          color: isMe ? t.bubbleMeText.withValues(alpha: 0.6) : t.textTertiary,
          fontSize: 13 * appState.chatTextScale,
        ),
      );
    }

    if (message.wilted) {
      return WiltedTombstone(isMe: isMe);
    }

    if (message.isPendingDownload) {
      return DownloadBubble(
        message: message,
        contact: group,
        appState: appState,
      );
    }

    if (message.ephemeral && !isMe && message.openedAt == null) {
      return WiltGate(
        message: message,
        onTap: () => appState.revealEphemeral(group, message),
      );
    }

    return wrapWiltingContent(
      context: context,
      message: message,
      isMe: isMe,
      content: _buildContentInner(context, t, l10n),
    );
  }

  Widget _buildContentInner(
    BuildContext context,
    WiltkeyTokens t,
    AppLocalizations l10n,
  ) {
    final ct = message.contentType;
    if (ct == 'pixel_art') {
      return PixelArtMessageCard(
        hexString: message.decryptedText ?? displayText,
        isSentByMe: isMe,
      );
    }
    if (ct == 'image' || ct == 'image_hidden') {
      return _buildImageContent(context, t, l10n);
    }
    if (ct == 'video') {
      return VideoMessageBubble(
        appState: appState,
        contact: group,
        message: message,
      );
    }
    if (ct == 'voice') {
      if (message.decodedAudioBytes == null) {
        try {
          message.decodedAudioBytes = base64Decode(
            message.decryptedText ?? displayText,
          );
        } catch (_) {}
      }
      return VoiceMessagePlayer(message: message);
    }

    final scale = appState.chatTextScale;
    final textColor = isMe ? t.bubbleMeText : t.textPrimary;

    // Sticker payload
    final sticker = stickerPayload(displayText);
    if (sticker != null) {
      final m = RegExp(r'^:([a-z0-9_]{2,32}):$').firstMatch(sticker);
      if (m != null) {
        final emoji = emojiMap[m.group(1)];
        if (emoji != null) {
          final side = 88.0 * scale;
          return Image.memory(
            emoji.bytes,
            width: side,
            height: side,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => Text(
              sticker,
              style: TextStyle(color: textColor, fontSize: 56 * scale),
            ),
          );
        }
      }
      return Text(sticker, style: TextStyle(fontSize: 56 * scale, height: 1.1));
    }

    final jumbo = jumboEmojiCount(displayText, emojiMap);
    if (jumbo != null) {
      final base = jumbo == 1 ? 40.0 : (jumbo <= 3 ? 34.0 : 26.0);
      return EmojiText(
        text: displayText,
        emojiMap: emojiMap,
        style: t.body.copyWith(
          color: textColor,
          fontSize: base * scale,
          height: 1.15,
        ),
        emojiSize: base * 1.25 * scale,
      );
    }

    // Build groupMembersMap mapping shortcode uppercase -> display name
    final Map<String, String> membersMap = {};
    final cached = appState.groupProfilesCache[group.id];
    if (cached != null) {
      for (final entry in cached.entries) {
        final p = entry.value;
        final name = p['name'] ?? '';
        final short = p['short_nick'] ??
            GroupMentionCandidate.deriveShortCode(name, entry.key);
        if (short.isNotEmpty) {
          membersMap[short.toUpperCase()] = name.isNotEmpty ? name : short;
        }
      }
    }
    if (group.isHost) {
      membersMap[appState.effectiveShortNick.toUpperCase()] =
          appState.effectiveDeviceName;
    } else if (group.hostKeyHash != null) {
      final hostName = group.hostName ?? 'Host';
      final hostShort = GroupMentionCandidate.deriveShortCode(
        hostName,
        group.hostKeyHash!,
      );
      membersMap[hostShort.toUpperCase()] = hostName;
    }

    // Markdown rich text with clickable links, mentions, and token fidelity
    return ChatMarkdownText(
      text: displayText,
      emojiMap: emojiMap,
      style: t.body.copyWith(
        color: textColor,
        fontSize: 14.5 * scale,
        height: 1.4,
      ),
      linkColor: isMe ? t.bubbleMeText : t.action,
      emojiSize: 20 * scale,
      scale: scale,
      myShortNick: appState.effectiveShortNick,
      groupMembersMap: membersMap,
      onMentionTap: onMemberTap != null
          ? (shortCode) {
              // Lookup member keyHash for shortcode if tapped
              final upper = shortCode.toUpperCase();
              for (final entry in (cached ?? {}).entries) {
                final p = entry.value;
                final name = p['name'] ?? '';
                final short = p['short_nick'] ??
                    GroupMentionCandidate.deriveShortCode(name, entry.key);
                if (short.toUpperCase() == upper) {
                  onMemberTap!(entry.key, name);
                  return;
                }
              }
            }
          : null,
    );
  }

  Widget _buildImageContent(
    BuildContext context,
    WiltkeyTokens t,
    AppLocalizations l10n,
  ) {
    if (message.contentType == 'image') {
      return ChatImageThumbnail(
        appState: appState,
        contact: group,
        message: message,
      );
    }

    final String? b64 = message.decryptedText;
    if (b64 == null || b64.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(t.action),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            t.uppercaseLabels
                ? l10n.groupDecryptingImage.toUpperCase()
                : l10n.groupDecryptingImage,
            style: t.dataMono.copyWith(color: t.action, fontSize: 11),
          ),
        ],
      );
    }

    final bool isHidden = message.contentType == 'image_hidden';
    final bool revealed = revealedImageIds.contains(message.id);

    if (isHidden && !revealed) {
      int rawSize = 0;
      try {
        rawSize = base64Decode(b64).length;
      } catch (_) {}
      return GestureDetector(
        onTap: () => onRevealImage?.call(message.id),
        child: Container(
          width: 200,
          height: 120,
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(
              color: t.action.withValues(alpha: 0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(t.radiusControl),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility_off_outlined, color: t.action, size: 28),
              const SizedBox(height: 8),
              Text(
                t.uppercaseLabels
                    ? l10n.groupTapToRevealImage.toUpperCase()
                    : l10n.groupTapToRevealImage,
                style: t.dataMono.copyWith(color: t.action, fontSize: 10),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.groupImageSize(AppState.formatBytes(rawSize)),
                style: t.dataMono.copyWith(
                  color: t.textTertiary,
                  fontSize: 8.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Uint8List? imageBytes = message.decodedImageBytes;
    if (imageBytes == null) {
      try {
        imageBytes = base64Decode(b64);
        message.decodedImageBytes = imageBytes;
      } catch (_) {}
    }

    if (imageBytes == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.radiusControl),
          border: Border.all(color: t.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, color: t.danger, size: 16),
            const SizedBox(width: 6),
            Text(
              l10n.groupImageFailedToLoad,
              style: t.bodySecondary.copyWith(fontSize: 10),
            ),
          ],
        ),
      );
    }

    final bytes = imageBytes;
    return GestureDetector(
      onTap: () => ImageViewerScreen.open(
        context,
        imageBytes: bytes,
        allowSave: message.allowSave,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300, maxWidth: 260),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(t.radiusControl),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(t.radiusControl),
                border: Border.all(color: t.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, color: t.danger, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    l10n.groupImageFailedToLoad,
                    style: t.bodySecondary.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(
    WiltkeyTokens t,
    AppLocalizations l10n,
    Color metaColor,
  ) {
    if (message.isPending) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 8,
            height: 8,
            child: CircularProgressIndicator(
              strokeWidth: 1.3,
              valueColor: AlwaysStoppedAnimation<Color>(metaColor),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            l10n.chatEncrypting,
            style: t.dataMono.copyWith(fontSize: 9, color: metaColor),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}${message.isEdited ? ' · ${l10n.chatEditedTag}' : ''}',
          style: t.dataMono.copyWith(color: metaColor),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          message.isFailed
              ? Icon(Icons.error_outline, color: t.warning, size: 11)
              : Icon(
                  message.isDelivered ? Icons.done_all : Icons.check,
                  color: message.isDelivered ? t.action : t.textTertiary,
                  size: 10,
                ),
        ],
      ],
    );
  }
}
