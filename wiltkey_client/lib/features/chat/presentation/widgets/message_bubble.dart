import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/state.dart';
import '../../../../core/models.dart';
import '../../../../core/custom_emoji.dart';
import '../../../../core/pixel_art_avatar.dart';
import '../../../../core/cosmetics/avatar_border_controller.dart';
import '../../../../core/theme/wk.dart';
import '../../../../core/theme/wiltkey_tokens.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import 'voice_message_player.dart';
import 'download_bubble.dart';
import 'reactions.dart';
import 'chat_image_thumbnail.dart';
import 'chat_markdown.dart';
import 'reply_preview.dart';
import 'wilt_widgets.dart';
import 'pixel_art_message_bubble.dart';

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

  /// Tapping the quoted-parent block (if this message is a reply) scrolls the
  /// list to the original message. Null disables the tap on the quote.
  final VoidCallback? onQuoteTap;

  /// Live shared emoji pool for this chat (name -> emoji); empty when none.
  final Map<String, CustomEmoji> emojiMap;

  /// Callback when user chooses to edit this message.
  final void Function(ChatMessage message)? onEdit;

  /// Callback when user chooses to delete this message.
  final void Function(ChatMessage message)? onDelete;

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
    this.onQuoteTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;

    // Contact-request control cards render before the generic system pill so
    // they can host their own status line / Approve-Deny buttons. They're stored
    // as plaintext JSON control payloads (senderId 'system', never OTP-encrypted)
    // — see state_contacts.dart.
    if (message.contentType == 'contact_request_sent' ||
        message.contentType == 'contact_request_received') {
      return _buildContactRequestCard(t, l10n);
    }

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
    // Inter-message spacing lives on the outer Column (as a trailing spacer)
    // rather than the bubble's own margin, so a reactions row can sit flush under
    // its bubble instead of being pushed down into the gap above the next message.
    final double batchGap = isFirstInBatch ? 12 : 4;
    final Widget bubble = Container(
      margin: EdgeInsets.zero,
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
          buildReplyQuoteFor(
                context,
                appState,
                contact,
                message,
                onTap: onQuoteTap,
              ) ??
              const SizedBox.shrink(),
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
                      '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}${message.isEdited ? ' · ${l10n.chatEditedTag}' : ''}',
                      style: t.dataMono.copyWith(
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
    // Long-press any settled bubble to react; a failed bubble keeps its tap-to-
    // retry. Pending bubbles aren't reactable yet (no stable persisted target).
    final Widget bubbleWidget = GestureDetector(
      onTap: (message.isFailed && onFailedTap != null) ? onFailedTap : null,
      onLongPress: message.isPending
          ? null
          : () {
              FocusManager.instance.primaryFocus?.unfocus();
              showReactionPicker(
                context,
                appState: appState,
                contact: contact,
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
              ? PixelArtAvatar(
                  hexString:
                      (contact.profileImageB64 != null &&
                          contact.profileImageB64!.isNotEmpty)
                      ? contact.profileImageB64!
                      : PixelArtAvatar.generateIdenticon(contact.keyHash),
                  size: 28,
                  borderId: contact.avatarBorderId,
                )
              : const SizedBox(width: 28),
          const SizedBox(width: 8),
        ],
        // Expanded + Align pins the bubble to its owner's side: mine hugs the
        // right edge, theirs the left. (A bare Flexible leaves the bubble
        // drifting toward the centre.) The bubble keeps its own maxWidth cap.
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
                  contact: contact,
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
                  hexString: appState.profileImageB64.isNotEmpty
                      ? appState.profileImageB64
                      : PixelArtAvatar.generateIdenticon(appState.userId),
                  size: 28,
                  borderId: AvatarBorderController.instance.borderId,
                )
              : const SizedBox(width: 28),
        ],
      ],
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final scale = appState.chatTextScale;

    // Screenshot-request card: an in-history control message (Accept/Decline),
    // expires into "request expired" via the wilt engine. Handled first so a
    // wilted request renders its own expired state, not the generic tombstone.
    if (message.contentType == 'screenshot_request') {
      return _buildScreenshotCard(t, l10n);
    }

    // Deleted messages render as a tombstone line.
    if (message.isDeleted) {
      return Text(
        l10n.chatMessageDeleted,
        style: t.bodySecondary.copyWith(
          fontStyle: FontStyle.italic,
          color: isMe ? t.bubbleMeText.withValues(alpha: 0.6) : t.textTertiary,
          fontSize: 13 * scale,
        ),
      );
    }

    // Wilting (disappearing) messages. Handled BEFORE the decrypt block so a
    // received message we haven't revealed is never decrypted — it stays a gate.
    if (message.wilted) return WiltedTombstone(isMe: isMe);

    // Large payload still parked on the relay: there IS no ciphertext to decrypt
    // yet, so this precedes both the wilt gate (revealing would open an empty
    // body and start its countdown) and the decrypt branch (which would spin
    // forever). Downloading only fetches the bytes — a wilting message still has
    // to be tapped to reveal afterwards, so the countdown is unaffected.
    if (message.isPendingDownload) {
      return DownloadBubble(
        message: message,
        contact: contact,
        appState: appState,
      );
    }

    if (message.ephemeral && !isMe && message.openedAt == null) {
      return WiltGate(
        message: message,
        onTap: () => appState.revealEphemeral(contact, message),
      );
    }

    // Plain images render through the lazy, fixed-size thumbnail — which fetches,
    // decrypts and decodes its OWN bytes on first build (i.e. when scrolled into
    // view). This MUST precede the generic "decrypting…" gate below: a deferred
    // image has no in-memory body yet and must not spin there. Wilting images
    // reach here only once revealed (the gate above catches unopened ones).
    if (message.contentType == 'image') {
      return wrapWiltingContent(
        context: context,
        message: message,
        isMe: isMe,
        content: ChatImageThumbnail(
          appState: appState,
          contact: contact,
          message: message,
        ),
      );
    }

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

    if (message.contentType == 'pixel_art') {
      return wrapWiltingContent(
        context: context,
        message: message,
        isMe: isMe,
        content: PixelArtMessageCard(
          hexString: decryptedText,
          isSentByMe: isMe,
        ),
      );
    }

    if (message.contentType == 'voice') {
      if (message.decodedAudioBytes == null) {
        try {
          message.decodedAudioBytes = base64Decode(decryptedText);
        } catch (_) {}
      }
      return VoiceMessagePlayer(message: message);
    }

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

      // Revealed hidden image → the same fixed-size lazy thumbnail as plain
      // images (it decodes the already-in-memory revealed body, no DB round-trip).
      return wrapWiltingContent(
        context: context,
        message: message,
        isMe: isMe,
        content: ChatImageThumbnail(
          appState: appState,
          contact: contact,
          message: message,
        ),
      );
    }

    final textColor = isMe ? t.bubbleMeText : t.textPrimary;

    // Sticker: render the single emoji / custom token large and on its own.
    final sticker = stickerPayload(decryptedText);
    if (sticker != null) {
      return wrapWiltingContent(
        context: context,
        message: message,
        isMe: isMe,
        content: _buildSticker(sticker, textColor, scale),
      );
    }

    final jumbo = jumboEmojiCount(decryptedText, emojiMap);
    if (jumbo != null) {
      final base = jumbo == 1 ? 40.0 : (jumbo <= 3 ? 34.0 : 26.0);
      return wrapWiltingContent(
        context: context,
        message: message,
        isMe: isMe,
        content: EmojiText(
          text: decryptedText,
          emojiMap: emojiMap,
          style: t.body.copyWith(
            color: textColor,
            fontSize: base * scale,
            height: 1.15,
          ),
          emojiSize: base * 1.25 * scale,
        ),
      );
    }

    return wrapWiltingContent(
      context: context,
      message: message,
      isMe: isMe,
      content: ChatMarkdownText(
        text: decryptedText,
        emojiMap: emojiMap,
        style: t.body.copyWith(
          color: textColor,
          fontSize: 15.5 * scale,
          height: 1.4,
        ),
        linkColor: isMe ? t.bubbleMeText : t.action,
        emojiSize: 20 * scale,
        scale: scale,
      ),
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

  // --- Screenshot-request card ----------------------------------------------

  Widget _buildScreenshotCard(WiltkeyTokens t, AppLocalizations l10n) {
    Map<String, dynamic> p = {};
    try {
      p = jsonDecode(message.text) as Map<String, dynamic>;
    } catch (_) {}
    final rawName = (p['requester_name'] as String?)?.trim();
    final name = (rawName == null || rawName.isEmpty) ? contact.name : rawName;
    final status = message.wilted
        ? 'expired'
        : (p['status'] as String? ?? 'pending');

    if (status == 'pending') return _buildScreenshotPending(t, l10n, name);

    // Resolved / expired → a compact muted row.
    late final IconData icon;
    late final String label;
    late final Color color;
    switch (status) {
      case 'accepted':
        icon = Icons.check_circle_outline;
        color = t.action;
        label = l10n.screenshotRequestAllowed;
        break;
      case 'declined':
        icon = Icons.cancel_outlined;
        color = t.textTertiary;
        label = l10n.screenshotRequestDeclined;
        break;
      default: // expired
        icon = Icons.timer_off_outlined;
        color = t.textTertiary;
        label = l10n.screenshotRequestExpired;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: t.dataMono.copyWith(fontSize: 11.5, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenshotPending(
    WiltkeyTokens t,
    AppLocalizations l10n,
    String name,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.action.withValues(alpha: 0.06),
        border: Border.all(color: t.action.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.screenshot_monitor_outlined, size: 16, color: t.action),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.screenshotRequestInline(name),
                  style: t.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (message.openedAt != null && message.expiresAt != null) ...[
            const SizedBox(height: 7),
            WiltCountdownBar(
              openedAt: message.openedAt!,
              expiresAt: message.expiresAt!,
              color: t.action,
            ),
          ],
          const SizedBox(height: 9),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () =>
                    appState.respondToScreenshotCard(contact, message, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.textSecondary,
                  side: BorderSide(color: t.border),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radiusControl),
                  ),
                ),
                child: Text(l10n.pairRequestReject),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () =>
                    appState.respondToScreenshotCard(contact, message, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.action,
                  foregroundColor: t.onAction,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radiusControl),
                  ),
                ),
                child: Text(l10n.pairRequestAccept),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Contact-request card ------------------------------------------------

  Widget _buildContactRequestCard(WiltkeyTokens t, AppLocalizations l10n) {
    Map<String, dynamic> p = {};
    try {
      p = jsonDecode(message.text) as Map<String, dynamic>;
    } catch (_) {}
    final String? reqId = p['req_id'] as String?;
    final String status = p['status'] as String? ?? 'pending';
    final bool received = message.contentType == 'contact_request_received';
    final String peerName = received
        ? (p['requester_name'] as String? ?? contact.name)
        : (p['target_name'] as String? ?? contact.name);
    final bool pending = status == 'pending';

    final String title;
    switch (status) {
      case 'accepted':
        title = l10n.contactRequestApproved;
        break;
      case 'declined':
        title = l10n.contactRequestDeclined;
        break;
      default:
        title = received
            ? l10n.contactRequestReceived(peerName)
            : l10n.contactRequestSent(peerName);
    }
    final Color accent = status == 'declined' ? t.textTertiary : t.action;

    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
          borderRadius: BorderRadius.circular(t.radiusCard),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  received ? Icons.person_add_alt : Icons.person_add,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (pending && received && reqId != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () =>
                        appState.respondToContactRequest(contact, reqId, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.textSecondary,
                      side: BorderSide(color: t.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radiusControl),
                      ),
                    ),
                    child: Text(l10n.contactRequestDeny),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () =>
                        appState.respondToContactRequest(contact, reqId, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.action,
                      foregroundColor: t.onAction,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(t.radiusControl),
                      ),
                    ),
                    child: Text(l10n.contactRequestApprove),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

