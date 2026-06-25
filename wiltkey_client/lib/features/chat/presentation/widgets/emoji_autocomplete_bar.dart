import 'package:flutter/material.dart';
import '../../../../core/custom_emoji.dart';
import '../../../../core/theme/wk.dart';

/// Returns the in-progress emoji query (the text after an open `:`, without the
/// colon) when the caret sits inside an unclosed `:[a-z0-9_]+` token; otherwise
/// null. Pure + side-effect free so it can be unit-tested directly.
///
/// Examples (caret marked `|`):
///   `hello :wav|`     -> "wav"
///   `:smile:|`        -> null   (the token is already closed)
///   `:|`              -> null   (nothing typed after the colon yet)
///   `a b|`            -> null   (no open colon)
String? activeEmojiQuery(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) cursor = text.length;
  int i = cursor - 1;
  while (i >= 0) {
    final c = text[i];
    if (c == ':') {
      final q = text.substring(i + 1, cursor).toLowerCase();
      if (q.isEmpty || q.length > 32) return null;
      return q;
    }
    if (!_isNameChar(c)) return null;
    i--;
  }
  return null;
}

bool _isNameChar(String c) {
  final code = c.codeUnitAt(0);
  return (code >= 0x61 && code <= 0x7A) || // a-z
      (code >= 0x41 && code <= 0x5A) || // A-Z (typed before lowercasing)
      (code >= 0x30 && code <= 0x39) || // 0-9
      code == 0x5F; // _
}

/// A horizontal strip of custom-emoji suggestions shown above the message input.
/// When the user is typing an open `:query`, it lists matching emojis; tapping
/// one replaces the fragment with the full `:name: ` token. Hidden when there's
/// no active query or no matches.
///
/// Reads the live controller state at build time, so the host screen only needs
/// to rebuild on text/selection changes (both chat inputs already do via their
/// char-count listener).
class EmojiAutocompleteBar extends StatelessWidget {
  final TextEditingController controller;
  final Map<String, CustomEmoji> emojiMap;

  const EmojiAutocompleteBar({
    super.key,
    required this.controller,
    required this.emojiMap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    if (emojiMap.isEmpty) return const SizedBox.shrink();

    final text = controller.text;
    final sel = controller.selection;
    final cursor = sel.isValid ? sel.baseOffset : text.length;
    final query = activeEmojiQuery(text, cursor);
    if (query == null) return const SizedBox.shrink();

    final matches =
        emojiMap.values.where((e) => e.name.startsWith(query)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    if (matches.isEmpty) return const SizedBox.shrink();

    // The opening colon sits one char before the query fragment.
    final colonIndex = cursor - query.length - 1;

    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.radiusControl),
        border: Border.all(color: t.action.withValues(alpha: 0.25)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: matches.length > 24 ? 24 : matches.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final emoji = matches[index];
          return InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => _insert(emoji, colonIndex, cursor),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Image.memory(
                    emoji.bytes,
                    width: 24,
                    height: 24,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image,
                      size: 20,
                      color: Colors.white24,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ':${emoji.name}:',
                    style: t.dataMono.copyWith(color: t.action, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Replaces the open `:query` fragment with the full `:name: ` token and moves
  /// the caret to just after the inserted trailing space.
  void _insert(CustomEmoji emoji, int colonIndex, int cursor) {
    final text = controller.text;
    if (colonIndex < 0 || cursor > text.length) return;
    final insertion = '${emoji.token} ';
    final newText = text.replaceRange(colonIndex, cursor, insertion);
    final newCursor = colonIndex + insertion.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }
}
