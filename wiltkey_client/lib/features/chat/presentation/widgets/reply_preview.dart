import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/models.dart';
import '../../../../core/state.dart';
import '../../../../core/custom_emoji.dart';
import '../../../../core/theme/wk.dart';

/// One-line preview text for a message being quoted in a reply (both the composer
/// "replying to" bar and the in-bubble quote). Content-type aware; falls back to a
/// generic label when there's no showable text (unrevealed/wilted/control).
String replyPreviewText(ChatMessage m, AppLocalizations l10n) {
  if (m.wilted) return l10n.wiltedMessage;
  if (m.contentType == 'image' || m.contentType == 'image_hidden') {
    return l10n.replyPreviewImage;
  }
  if (m.contentType == 'voice') return l10n.replyPreviewVoice;
  if (m.contentType == 'screenshot_request') return l10n.replyPreviewMessage;
  final text = (m.decryptedText ?? '').trim();
  if (text.isEmpty) return l10n.replyPreviewMessage;
  return stickerPayload(text) ?? text;
}

/// Author label for a quoted message ("You" for our own, else the resolved peer /
/// group-member name, else a generic fallback).
String replyAuthorName(
  ChatMessage m,
  Contact contact,
  AppState app,
  AppLocalizations l10n,
) {
  if (m.isSentByMe) return l10n.replyYou;
  return app.peerNameForMessage(contact, m) ?? l10n.replySomeone;
}

/// Builds the in-bubble quoted-parent block for [message] if it's a reply, else
/// null. Resolves the parent from the loaded window; a dangling / not-loaded
/// parent renders the muted "unavailable" quote. [onMyBubble] styling follows the
/// replying message's own side. Shared by the 1-on-1 bubble and the group bubble.
Widget? buildReplyQuoteFor(
  BuildContext context,
  AppState app,
  Contact contact,
  ChatMessage message, {
  VoidCallback? onTap,
}) {
  final parentId = message.replyToId;
  if (parentId == null) return null;
  final l10n = AppLocalizations.of(context)!;
  final parent = app.loadedMessageById(contact.id, parentId);
  final Widget quote = parent == null
      ? ReplyQuote.unavailableQuote(l10n, onMyBubble: message.isSentByMe)
      : ReplyQuote(
          author: replyAuthorName(parent, contact, app, l10n),
          preview: replyPreviewText(parent, l10n),
          onMyBubble: message.isSentByMe,
          onTap: onTap,
        );
  return Padding(padding: const EdgeInsets.only(bottom: 5), child: quote);
}

/// A compact quoted-message block: an accent stripe, the author, and a truncated
/// one-line preview. Reused by the composer reply bar ([onClose] shows an ✕) and
/// the in-bubble quote ([onTap] can scroll to the original). [unavailable] renders
/// the muted "original unavailable" state for a dangling / wilted parent.
class ReplyQuote extends StatelessWidget {
  final String author;
  final String preview;
  final VoidCallback? onClose;
  final VoidCallback? onTap;
  final bool unavailable;
  final bool onMyBubble;

  const ReplyQuote({
    super.key,
    required this.author,
    required this.preview,
    this.onClose,
    this.onTap,
    this.unavailable = false,
    this.onMyBubble = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final Color stripe = onMyBubble ? t.bubbleMeText : t.action;
    final Color authorColor = onMyBubble ? t.bubbleMeText : t.action;
    final Color previewColor = onMyBubble
        ? t.bubbleMeText.withValues(alpha: 0.75)
        : t.textSecondary;

    final Widget body = Container(
      padding: const EdgeInsets.fromLTRB(9, 6, 8, 6),
      decoration: BoxDecoration(
        color: (onMyBubble ? t.bubbleMeText : t.action).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(t.radiusControl),
        border: Border(left: BorderSide(color: stripe, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!unavailable)
                  Text(
                    author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.dataMono.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: authorColor,
                    ),
                  ),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySecondary.copyWith(
                    fontSize: 11.5,
                    color: previewColor,
                    fontStyle: unavailable ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          if (onClose != null)
            GestureDetector(
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.close, size: 16, color: t.textTertiary),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return body;
    return GestureDetector(onTap: onTap, child: body);
  }

  /// Convenience: the muted "original message unavailable" quote (dangling parent).
  static Widget unavailableQuote(
    AppLocalizations l10n, {
    bool onMyBubble = false,
  }) {
    return ReplyQuote(
      author: '',
      preview: l10n.replyUnavailable,
      unavailable: true,
      onMyBubble: onMyBubble,
    );
  }
}
