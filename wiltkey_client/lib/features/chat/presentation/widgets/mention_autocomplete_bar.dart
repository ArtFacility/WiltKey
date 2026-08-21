import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/pixel_art_avatar.dart';
import '../../../../core/theme/wk.dart';

/// Represents a group chat member candidate for `@mention` autocompletion.
class GroupMentionCandidate {
  final String keyHash;
  final String name;
  final String shortCode;
  final String profileImage;
  final String? avatarBorderId;
  final bool isMe;

  const GroupMentionCandidate({
    required this.keyHash,
    required this.name,
    required this.shortCode,
    this.profileImage = '',
    this.avatarBorderId,
    this.isMe = false,
  });

  /// Derives an uppercase alphanumeric shortcode (3-5 chars) from a display name or key hash.
  static String deriveShortCode(String name, String keyHash) {
    final clean = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (clean.isNotEmpty) {
      return clean.substring(0, min(5, clean.length)).toUpperCase();
    }
    if (keyHash.length >= 5) {
      return keyHash.substring(0, 5).toUpperCase();
    }
    return keyHash.toUpperCase();
  }
}

/// Returns the in-progress mention query (the text after an open `@`, without the
/// at-sign) when the caret sits inside an unclosed `@[a-zA-Z0-9_]*` token; otherwise
/// null.
///
/// Examples (caret marked `|`):
///   `hello @naur|`    -> "naur"
///   `@|`              -> "" (lists all members when user just typed @)
///   `@Alice `         -> null (closed with space)
///   `a b|`            -> null (no open at-sign)
String? activeMentionQuery(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) cursor = text.length;
  int i = cursor - 1;
  while (i >= 0) {
    final c = text[i];
    if (c == '@') {
      // Must be at start of string or preceded by whitespace/punctuation
      if (i == 0 || text[i - 1] == ' ' || text[i - 1] == '\n' || text[i - 1] == '\t') {
        final q = text.substring(i + 1, cursor);
        if (q.length > 32) return null;
        return q;
      }
      return null;
    }
    if (!_isMentionChar(c)) return null;
    i--;
  }
  return null;
}

bool _isMentionChar(String c) {
  final code = c.codeUnitAt(0);
  return (code >= 0x61 && code <= 0x7A) || // a-z
      (code >= 0x41 && code <= 0x5A) || // A-Z
      (code >= 0x30 && code <= 0x39) || // 0-9
      code == 0x5F; // _
}

/// A horizontal strip of member suggestions shown above the group message input
/// when the user types `@`. Tapping a member replaces `@query` with `@SHORTCODE `.
class MentionAutocompleteBar extends StatelessWidget {
  final TextEditingController controller;
  final List<GroupMentionCandidate> candidates;

  const MentionAutocompleteBar({
    super.key,
    required this.controller,
    required this.candidates,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    if (candidates.isEmpty) return const SizedBox.shrink();

    final text = controller.text;
    final sel = controller.selection;
    final cursor = sel.isValid ? sel.baseOffset : text.length;
    final query = activeMentionQuery(text, cursor);
    if (query == null) return const SizedBox.shrink();

    final lowerQ = query.toLowerCase();
    final matches = candidates.where((c) {
      if (lowerQ.isEmpty) return true;
      return c.name.toLowerCase().contains(lowerQ) ||
          c.shortCode.toLowerCase().contains(lowerQ);
    }).toList();

    if (matches.isEmpty) return const SizedBox.shrink();

    // The opening @ sits one char before the query fragment.
    final atIndex = cursor - query.length - 1;

    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.radiusControl),
        border: Border.all(color: t.action.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: matches.length > 20 ? 20 : matches.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final member = matches[index];
          final avatarHex = member.profileImage.isNotEmpty
              ? member.profileImage
              : PixelArtAvatar.generateIdenticon(member.keyHash);

          return InkWell(
            borderRadius: BorderRadius.circular(t.radiusControl),
            onTap: () => _insert(member, atIndex, cursor),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: member.isMe
                    ? t.action.withValues(alpha: 0.12)
                    : t.bg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(t.radiusControl),
                border: Border.all(
                  color: member.isMe
                      ? t.action.withValues(alpha: 0.4)
                      : t.border.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PixelArtAvatar(
                    hexString: avatarHex,
                    size: 22,
                    borderId: (member.avatarBorderId != null &&
                            member.avatarBorderId!.isNotEmpty)
                        ? member.avatarBorderId
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    member.name,
                    style: t.body.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: t.action.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '@${member.shortCode}',
                      style: t.dataMono.copyWith(
                        color: t.action,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Replaces the open `@query` fragment with `@SHORTCODE ` and moves caret after trailing space.
  void _insert(GroupMentionCandidate member, int atIndex, int cursor) {
    final text = controller.text;
    if (atIndex < 0 || cursor > text.length) return;
    final insertion = '@${member.shortCode} ';
    final newText = text.replaceRange(atIndex, cursor, insertion);
    final newCursor = atIndex + insertion.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }
}
