import 'dart:async';
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
import 'voice_message_player.dart';
import 'reactions.dart';
import 'image_viewer.dart';

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
    // Long-press any settled bubble to react; a failed bubble keeps its tap-to-
    // retry. Pending bubbles aren't reactable yet (no stable persisted target).
    final Widget bubbleWidget = GestureDetector(
      onTap: (message.isFailed && onFailedTap != null) ? onFailedTap : null,
      onLongPress: message.isPending
          ? null
          : () => showReactionPicker(
              context,
              appState: appState,
              contact: contact,
              message: message,
              emojiMap: emojiMap,
            ),
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
                )
              : const SizedBox(width: 28),
        ],
      ],
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;

    // Screenshot-request card: an in-history control message (Accept/Decline),
    // expires into "request expired" via the wilt engine. Handled first so a
    // wilted request renders its own expired state, not the generic tombstone.
    if (message.contentType == 'screenshot_request') {
      return _buildScreenshotCard(t, l10n);
    }

    // Wilting (disappearing) messages. Handled BEFORE the decrypt block so a
    // received message we haven't revealed is never decrypted — it stays a gate.
    if (message.wilted) return _buildWiltedTombstone(t, l10n);
    if (message.ephemeral && !isMe && message.openedAt == null) {
      return _buildWiltGate(t, l10n);
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

      Uint8List? imageBytes = message.decodedImageBytes;
      if (imageBytes == null) {
        try {
          imageBytes = base64Decode(decryptedText);
          message.decodedImageBytes = imageBytes;
        } catch (_) {}
      }

      if (imageBytes != null) {
        final bytes = imageBytes;
        return _wrapWilting(
          t,
          l10n,
          GestureDetector(
            onTap: () => ImageViewerScreen.open(
              context,
              imageBytes: bytes,
              // A wilting image is never downloadable, regardless of allowSave.
              allowSave: message.allowSave && !message.ephemeral,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300, maxWidth: 280),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(t.radiusControl),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _imageError(t, l10n),
                ),
              ),
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
      return _wrapWilting(t, l10n, _buildSticker(sticker, textColor, scale));
    }

    final jumbo = jumboEmojiCount(decryptedText, emojiMap);
    if (jumbo != null) {
      final base = jumbo == 1 ? 40.0 : (jumbo <= 3 ? 34.0 : 26.0);
      return _wrapWilting(
        t,
        l10n,
        EmojiText(
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
    return _wrapWilting(
      t,
      l10n,
      EmojiText(
        text: decryptedText,
        emojiMap: emojiMap,
        style: t.body.copyWith(
          color: textColor,
          fontSize: 13 * scale,
          height: 1.4,
        ),
        emojiSize: 20 * scale,
      ),
    );
  }

  // --- Wilting message UI ----------------------------------------------------

  /// Wraps a revealed wilting message's [content] with its countdown footer (a
  /// received message that's been opened) or a small "wilting" tag (our own copy,
  /// which wilts on the peer's confirmation rather than a timer). Non-ephemeral
  /// messages pass through untouched.
  Widget _wrapWilting(
    WiltkeyTokens t,
    AppLocalizations l10n,
    Widget content,
  ) {
    if (!message.isWilting) return content;
    final accent = isMe ? t.bubbleMeText : t.action;
    final Widget footer;
    if (message.openedAt != null && message.expiresAt != null) {
      footer = _WiltCountdownBar(
        openedAt: message.openedAt!,
        expiresAt: message.expiresAt!,
        color: accent,
      );
    } else {
      // Our own copy (or an opened-timer not yet stamped): a static tag.
      footer = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_florist_outlined, size: 11, color: accent.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(
            t.uppercaseLabels
                ? l10n.wiltingMessageTag.toUpperCase()
                : l10n.wiltingMessageTag,
            style: t.dataMono.copyWith(fontSize: 9, color: accent.withValues(alpha: 0.7)),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [content, const SizedBox(height: 5), footer],
    );
  }

  /// The gated placeholder for a received, not-yet-revealed wilting message. Tap
  /// reveals it (stamping the countdown) via [AppStateWilting.revealEphemeral].
  Widget _buildWiltGate(WiltkeyTokens t, AppLocalizations l10n) {
    final secs = message.ttlSeconds <= 0 ? 5 : message.ttlSeconds;
    return GestureDetector(
      onTap: () => appState.revealEphemeral(contact, message),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: t.action.withValues(alpha: 0.08),
          border: Border.all(color: t.action.withValues(alpha: 0.35), width: 1),
          borderRadius: BorderRadius.circular(t.radiusControl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_florist_outlined, color: t.action, size: 16),
            const SizedBox(width: 8),
            Text(
              t.uppercaseLabels
                  ? l10n.wiltingTapToReveal.toUpperCase()
                  : l10n.wiltingTapToReveal,
              style: t.dataMono.copyWith(color: t.action, fontSize: 11),
            ),
            const SizedBox(width: 6),
            Text(
              '${secs}s',
              style: t.dataMono.copyWith(color: t.textTertiary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  /// The tombstone left after a message has wilted (content destroyed).
  Widget _buildWiltedTombstone(WiltkeyTokens t, AppLocalizations l10n) {
    final color = isMe ? t.bubbleMeText.withValues(alpha: 0.6) : t.textTertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_florist_outlined, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          t.uppercaseLabels
              ? l10n.wiltedMessage.toUpperCase()
              : l10n.wiltedMessage,
          style: t.dataMono.copyWith(
            fontSize: 11.5,
            color: color,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
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
            _WiltCountdownBar(
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

/// A self-ticking draining bar for an opened wilting message: full at open,
/// empty at expiry. Purely visual — the actual destruction is driven by the
/// [AppStateWilting] timer, which rebuilds this bubble into a tombstone. Ticks a
/// few times a second and stops itself once drained.
class _WiltCountdownBar extends StatefulWidget {
  final int openedAt;
  final int expiresAt;
  final Color color;
  const _WiltCountdownBar({
    required this.openedAt,
    required this.expiresAt,
    required this.color,
  });

  @override
  State<_WiltCountdownBar> createState() => _WiltCountdownBarState();
}

class _WiltCountdownBarState extends State<_WiltCountdownBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (!mounted || _fraction() <= 0) {
        t.cancel();
        return;
      }
      setState(() {});
    });
  }

  double _fraction() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final span = widget.expiresAt - widget.openedAt;
    if (span <= 0) return 0;
    return ((widget.expiresAt - now) / span).clamp(0.0, 1.0);
  }

  int _secondsLeft() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ((widget.expiresAt - now) / 1000).ceil().clamp(0, 999);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frac = _fraction();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 90,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 4,
              backgroundColor: widget.color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(widget.color),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${_secondsLeft()}s',
          style: TextStyle(
            fontSize: 9,
            color: widget.color.withValues(alpha: 0.8),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
