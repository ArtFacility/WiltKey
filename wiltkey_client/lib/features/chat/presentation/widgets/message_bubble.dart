import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/state.dart';
import '../../../../core/models.dart';
import '../../../../core/custom_emoji.dart';
import '../../../../core/pixel_art_avatar.dart';
import '../../../../core/theme/wk.dart';
import '../../../../core/theme/wiltkey_tokens.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String displayText;
  final Contact contact;
  final AppState appState;
  final bool isMe;
  final bool isRevealed;
  final VoidCallback onRevealTap;
  final VoidCallback? onFailedTap;
  final bool isFirstInBatch;

  /// Live shared emoji pool for this chat (name -> emoji); empty when none.
  final Map<String, CustomEmoji> emojiMap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.displayText,
    required this.contact,
    required this.appState,
    required this.isMe,
    required this.isRevealed,
    required this.onRevealTap,
    this.onFailedTap,
    required this.isFirstInBatch,
    this.emojiMap = const {},
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;

    if (message.isSystem) {
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

    // A sticker (emoji/`:name:` sent via long-press) renders big and bubble-less:
    // no fill, no border, tight padding — just the glyph with a faint timestamp.
    final String? sticker = message.decryptedText == null
        ? null
        : stickerPayload(message.decryptedText!);
    final bool isSticker = sticker != null;
    // Meta (timestamp/encrypting) colour: on a transparent sticker the
    // on-bubble "my text" colour can wash out, so fall back to the tertiary tone.
    final Color metaColor = isSticker
        ? t.textTertiary
        : (isMe ? t.bubbleMeText.withValues(alpha: 0.6) : t.textTertiary);

    const double tail = 6;
    final Widget bubble = Container(
      margin: EdgeInsets.only(bottom: isFirstInBatch ? 12 : 4),
      padding: isSticker
          ? const EdgeInsets.symmetric(horizontal: 2, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: isSticker
          ? const BoxDecoration()
          : BoxDecoration(
              color: isMe ? t.bubbleMe : t.bubbleThem,
              border: Border.all(
                color: message.isFailed
                    ? t.warning
                    : (isMe ? t.bubbleMeBorder : t.bubbleThemBorder),
                width: message.isFailed ? 1.5 : t.borderWidth,
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
          _buildMessageContent(context),
          const SizedBox(height: 4),
          message.isPending
              ? Row(
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
                      style: t.dataMono.copyWith(
                        fontSize: 9,
                        color: metaColor,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                      style: t.dataMono.copyWith(
                        fontSize: 9,
                        color: metaColor,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      message.isFailed
                          ? Icon(
                              Icons.error_outline,
                              color: t.warning,
                              size: 11,
                            )
                          : Icon(
                              message.isDelivered
                                  ? Icons.done_all
                                  : Icons.check,
                              color: message.isDelivered
                                  ? t.action
                                  : t.textTertiary,
                              size: 10,
                            ),
                    ],
                  ],
                ),
        ],
      ),
    );

    // Pending sends render dimmed until the ciphertext is ready.
    final Widget shownBubble = message.isPending
        ? Opacity(opacity: 0.6, child: bubble)
        : bubble;
    final Widget bubbleWidget = message.isFailed && onFailedTap != null
        ? GestureDetector(onTap: onFailedTap, child: shownBubble)
        : shownBubble;

    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) ...[
          isFirstInBatch
              ? PixelArtAvatar(
                  hexString:
                      (contact.profileImageB64 != null &&
                          contact.profileImageB64!.isNotEmpty)
                      ? contact.profileImageB64!
                      : PixelArtAvatar.generateIdenticon(contact.keyHash),
                  size: 28,
                )
              : const SizedBox(width: 28),
          const SizedBox(width: 8),
        ],
        Flexible(child: bubbleWidget),
        if (isMe) ...[
          const SizedBox(width: 8),
          isFirstInBatch
              ? PixelArtAvatar(
                  hexString: appState.profileImageB64.isNotEmpty
                      ? appState.profileImageB64
                      : PixelArtAvatar.generateIdenticon(appState.userId),
                  size: 28,
                )
              : const SizedBox(width: 28),
        ],
      ],
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;

    if (message.decryptedText == null && !message.isFailed) {
      appState.decryptMessage(contact, message);

      final shortHash = message.text.length > 8
          ? message.text.substring(0, 8)
          : message.text;
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
            t.uppercaseLabels ? '[LOCKED: 0x$shortHash]' : 'Decrypting…',
            style: t.dataMono.copyWith(color: t.action, fontSize: 11),
          ),
        ],
      );
    }

    final decryptedText = message.decryptedText ?? displayText;

    if (message.contentType == 'image' ||
        message.contentType == 'image_hidden') {
      final bool isHidden = message.contentType == 'image_hidden';
      if (isHidden && !isRevealed) {
        int rawSize = 0;
        try {
          rawSize = base64Decode(decryptedText).length;
        } catch (_) {}
        final sizeText = AppState.formatBytes(rawSize);

        return GestureDetector(
          onTap: onRevealTap,
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
                  l10n.groupImageSize(sizeText),
                  style: t.dataMono.copyWith(
                    fontSize: 8.5,
                    color: t.textTertiary,
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
          imageBytes = base64Decode(decryptedText);
          message.decodedImageBytes = imageBytes;
        } catch (_) {}
      }

      if (imageBytes != null) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300, maxWidth: 280),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(t.radiusControl),
            child: Image.memory(
              imageBytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _imageError(t, l10n),
            ),
          ),
        );
      } else {
        return _imageError(t, l10n);
      }
    }

    final scale = appState.chatTextScale;
    final textColor = isMe ? t.bubbleMeText : t.textPrimary;

    // Sticker: render the single emoji / custom token large and on its own.
    final sticker = stickerPayload(decryptedText);
    if (sticker != null) {
      return _buildSticker(sticker, textColor, scale);
    }

    final jumbo = jumboEmojiCount(decryptedText, emojiMap);
    if (jumbo != null) {
      final base = jumbo == 1 ? 40.0 : (jumbo <= 3 ? 34.0 : 26.0);
      return EmojiText(
        text: decryptedText,
        emojiMap: emojiMap,
        style: t.body.copyWith(
          color: textColor,
          fontSize: base * scale,
          height: 1.15,
        ),
        emojiSize: base * 1.25 * scale,
      );
    }
    return EmojiText(
      text: decryptedText,
      emojiMap: emojiMap,
      style: t.body.copyWith(
        color: textColor,
        fontSize: 13 * scale,
        height: 1.4,
      ),
      emojiSize: 20 * scale,
    );
  }

  /// Renders a sticker payload big and bubble-less: a custom `:name:` token as a
  /// large image (when it resolves in the pool), otherwise the unicode emoji as
  /// jumbo text. Falls back to plain text if a custom token no longer resolves.
  Widget _buildSticker(String payload, Color textColor, double scale) {
    final m = RegExp(r'^:([a-z0-9_]{2,32}):$').firstMatch(payload);
    if (m != null) {
      final emoji = emojiMap[m.group(1)];
      if (emoji != null) {
        final side = 104.0 * scale;
        return Image.memory(
          emoji.bytes,
          width: side,
          height: side,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => Text(
            payload,
            style: TextStyle(color: textColor, fontSize: 64 * scale),
          ),
        );
      }
    }
    return Text(
      payload,
      style: TextStyle(fontSize: 64 * scale, height: 1.1),
    );
  }

  Widget _imageError(WiltkeyTokens t, AppLocalizations l10n) {
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
}
