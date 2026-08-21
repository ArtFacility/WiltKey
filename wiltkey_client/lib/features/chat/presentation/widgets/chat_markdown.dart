import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/custom_emoji.dart';
import '../../../../core/theme/wk.dart';
import '../../../../core/theme/wiltkey_tokens.dart';
import 'link_warning_dialog.dart';

/// Renders a chat message body with full Markdown styling, auto-link detection,
/// inline code & code blocks, blockquotes, lists, headers, and inline custom emojis.
///
/// Tapping any URL or link opens the security [showLinkWarningDialog] before
/// launching the external browser.
class ChatMarkdownText extends StatelessWidget {
  final String text;
  final Map<String, CustomEmoji> emojiMap;
  final TextStyle style;
  final Color? linkColor;
  final double emojiSize;
  final double scale;
  final String? myShortNick;
  final Map<String, String>? groupMembersMap;
  final void Function(String shortCode)? onMentionTap;

  const ChatMarkdownText({
    super.key,
    required this.text,
    this.emojiMap = const {},
    required this.style,
    this.linkColor,
    this.emojiSize = 20,
    this.scale = 1.0,
    this.myShortNick,
    this.groupMembersMap,
    this.onMentionTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final effectiveLinkColor = linkColor ?? t.action;

    // If the text contains block-level markers (code blocks, headers, quotes, lists, newlines),
    // parse and build a structured block layout. Otherwise, build an inline rich text.
    final blocks = _parseBlocks(text);

    if (blocks.length == 1 && blocks.first is _ParagraphBlock) {
      return Text.rich(
        TextSpan(
          children: _buildInlineSpans(
            context,
            (blocks.first as _ParagraphBlock).text,
            style,
            effectiveLinkColor,
            t,
          ),
        ),
        style: style,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: 6 * scale),
          _buildBlockWidget(context, blocks[i], t, effectiveLinkColor),
        ],
      ],
    );
  }

  Widget _buildBlockWidget(
    BuildContext context,
    _Block block,
    WiltkeyTokens t,
    Color linkColor,
  ) {
    if (block is _CodeBlock) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: t.bg.withValues(alpha: 0.7),
          border: Border.all(color: t.border, width: t.borderWidth),
          borderRadius: BorderRadius.circular(t.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (block.language.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    block.language.toUpperCase(),
                    style: t.dataMono.copyWith(
                      fontSize: 9.5 * scale,
                      color: t.textTertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: block.code));
                      HapticFeedback.selectionClick();
                    },
                    child: Icon(Icons.copy, size: 14, color: t.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            SelectableText(
              block.code,
              style: t.dataMono.copyWith(
                fontSize: 12 * scale,
                color: t.textPrimary,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    if (block is _HeaderBlock) {
      final double headerSize = switch (block.level) {
        1 => (style.fontSize ?? 15) * 1.35,
        2 => (style.fontSize ?? 15) * 1.20,
        _ => (style.fontSize ?? 15) * 1.10,
      };
      final headerStyle = style.copyWith(
        fontSize: headerSize,
        fontWeight: FontWeight.bold,
        letterSpacing: block.level == 1 ? 0.3 : 0.0,
      );
      return Text.rich(
        TextSpan(
          children: _buildInlineSpans(
            context,
            block.text,
            headerStyle,
            linkColor,
            t,
          ),
        ),
        style: headerStyle,
      );
    }

    if (block is _QuoteBlock) {
      final quoteStyle = style.copyWith(
        color: style.color?.withValues(alpha: 0.85) ?? t.textSecondary,
        fontStyle: FontStyle.italic,
      );
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: t.action.withValues(alpha: 0.65),
              width: 3.0,
            ),
          ),
        ),
        child: Text.rich(
          TextSpan(
            children: _buildInlineSpans(
              context,
              block.text,
              quoteStyle,
              linkColor,
              t,
            ),
          ),
          style: quoteStyle,
        ),
      );
    }

    if (block is _ListItemBlock) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: block.prefix.length > 2 ? 26 * scale : 18 * scale,
            child: Text(
              block.prefix,
              style: style.copyWith(
                color: t.action,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: _buildInlineSpans(
                  context,
                  block.text,
                  style,
                  linkColor,
                  t,
                ),
              ),
              style: style,
            ),
          ),
        ],
      );
    }

    // Default Paragraph Block
    final para = block as _ParagraphBlock;
    return Text.rich(
      TextSpan(
        children: _buildInlineSpans(
          context,
          para.text,
          style,
          linkColor,
          t,
        ),
      ),
      style: style,
    );
  }

  // --- Inline Spans Parser ---

  List<InlineSpan> _buildInlineSpans(
    BuildContext context,
    String rawText,
    TextStyle baseStyle,
    Color linkColor,
    WiltkeyTokens t,
  ) {
    if (rawText.isEmpty) return const [];

    final List<InlineSpan> spans = [];

    // Tokenize inline markdown: links, code, custom emojis, mentions, bold, italic, strikethrough, underline
    final RegExp inlineRegex = RegExp(
      r'('
      r'\[(?<linkText>[^\]]+)\]\((?<linkUrl>[^\s\)]+)\)' // [title](url)
      r'|'
      r'(?<rawUrl>https?:\/\/[^\s<>()]+|www\.[^\s<>()]+)' // Auto URL
      r'|'
      r'`(?<code>[^`\n]+)`' // `code`
      r'|'
      r':(?<emojiName>[a-z0-9_]{2,32}):' // :custom_emoji:
      r'|'
      r'@(?<mentionName>[a-zA-Z0-9_]{2,16})' // @mention
      r'|'
      r'\*\*(?<boldText>[^\*\n]+)\*\*' // **bold**
      r'|'
      r'__(?<boldText2>[^_\n]+)__' // __bold__
      r'|'
      r'\*(?<italicText>[^\*\n]+)\*' // *italic*
      r'|'
      r'_(?<italicText2>[^_\n]+)_' // _italic_
      r'|'
      r'~~(?<strikeText>[^~\n]+)~~' // ~~strikethrough~~
      r'|'
      r'~(?<underlineText>[^~\n]+)~' // ~underline~
      r')',
      caseSensitive: false,
    );

    int lastIndex = 0;
    for (final match in inlineRegex.allMatches(rawText)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: rawText.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      final linkTitle = match.namedGroup('linkText');
      final linkUrl = match.namedGroup('linkUrl');
      final rawUrl = match.namedGroup('rawUrl');
      final code = match.namedGroup('code');
      final emojiName = match.namedGroup('emojiName');
      final mentionName = match.namedGroup('mentionName');
      final boldText =
          match.namedGroup('boldText') ?? match.namedGroup('boldText2');
      final italicText =
          match.namedGroup('italicText') ?? match.namedGroup('italicText2');
      final strikeText = match.namedGroup('strikeText');
      final underlineText = match.namedGroup('underlineText');

      if (linkTitle != null && linkUrl != null) {
        final parsedUri = Uri.tryParse(
          linkUrl.startsWith('http://') || linkUrl.startsWith('https://')
              ? linkUrl
              : 'https://$linkUrl',
        );
        spans.add(
          TextSpan(
            text: linkTitle,
            style: baseStyle.copyWith(
              color: linkColor,
              decoration: TextDecoration.underline,
              decorationColor: linkColor,
              fontWeight: FontWeight.w600,
            ),
            recognizer: parsedUri != null
                ? (TapGestureRecognizer()
                  ..onTap = () => showLinkWarningDialog(context, parsedUri))
                : null,
          ),
        );
      } else if (rawUrl != null) {
        final parsedUri = Uri.tryParse(
          rawUrl.startsWith('http://') || rawUrl.startsWith('https://')
              ? rawUrl
              : 'https://$rawUrl',
        );
        spans.add(
          TextSpan(
            text: rawUrl,
            style: baseStyle.copyWith(
              color: linkColor,
              decoration: TextDecoration.underline,
              decorationColor: linkColor,
            ),
            recognizer: parsedUri != null
                ? (TapGestureRecognizer()
                  ..onTap = () => showLinkWarningDialog(context, parsedUri))
                : null,
          ),
        );
      } else if (code != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: t.bg.withValues(alpha: 0.5),
                border: Border.all(color: t.border.withValues(alpha: 0.6), width: 1),
                borderRadius: BorderRadius.circular(t.radiusControl),
              ),
              child: Text(
                code,
                style: t.dataMono.copyWith(
                  fontSize: (baseStyle.fontSize ?? 14) * 0.9,
                  color: t.action,
                ),
              ),
            ),
          ),
        );
      } else if (emojiName != null && emojiMap.containsKey(emojiName)) {
        final emoji = emojiMap[emojiName]!;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.0),
              child: Image.memory(
                emoji.bytes,
                width: emojiSize,
                height: emojiSize,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) =>
                    Text(emoji.token, style: baseStyle),
              ),
            ),
          ),
        );
      } else if (mentionName != null) {
        final upper = mentionName.toUpperCase();
        final isMe = myShortNick != null && myShortNick!.toUpperCase() == upper;
        final displayName = groupMembersMap?[upper] ?? mentionName;

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: onMentionTap != null ? () => onMentionTap!(mentionName) : null,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
                padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isMe
                      ? t.action.withValues(alpha: 0.24)
                      : t.bg.withValues(alpha: 0.5),
                  border: Border.all(
                    color: isMe
                        ? t.action.withValues(alpha: 0.85)
                        : t.border.withValues(alpha: 0.6),
                    width: isMe ? 1.2 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(t.radiusControl),
                  boxShadow: isMe
                      ? [
                          BoxShadow(
                            color: t.action.withValues(alpha: 0.25),
                            blurRadius: 4,
                            spreadRadius: 0.5,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '@$displayName',
                  style: (isMe ? t.dataMono : baseStyle).copyWith(
                    color: isMe ? t.action : t.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: (baseStyle.fontSize ?? 14) * 0.92,
                  ),
                ),
              ),
            ),
          ),
        );
      } else if (boldText != null) {
        spans.add(
          TextSpan(
            text: boldText,
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (italicText != null) {
        spans.add(
          TextSpan(
            text: italicText,
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (strikeText != null) {
        spans.add(
          TextSpan(
            text: strikeText,
            style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
          ),
        );
      } else if (underlineText != null) {
        spans.add(
          TextSpan(
            text: underlineText,
            style: baseStyle.copyWith(decoration: TextDecoration.underline),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: match.group(0),
            style: baseStyle,
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < rawText.length) {
      spans.add(
        TextSpan(
          text: rawText.substring(lastIndex),
          style: baseStyle,
        ),
      );
    }

    return spans;
  }

  // --- Block Parser ---

  static List<_Block> _parseBlocks(String input) {
    final List<_Block> blocks = [];
    final lines = input.split('\n');

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      // 1. Code Block ```
      if (line.trimLeft().startsWith('```')) {
        final lang = line.trimLeft().substring(3).trim();
        final List<String> codeLines = [];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        if (i < lines.length) i++; // skip closing ```
        blocks.add(_CodeBlock(language: lang, code: codeLines.join('\n')));
        continue;
      }

      // 2. Headers (#, ##, ###)
      final headerMatch = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
      if (headerMatch != null) {
        final level = headerMatch.group(1)!.length;
        final text = headerMatch.group(2)!;
        blocks.add(_HeaderBlock(level: level, text: text));
        i++;
        continue;
      }

      // 3. Blockquotes (> ...)
      if (line.startsWith('> ') || line == '>') {
        final List<String> quoteLines = [];
        while (i < lines.length &&
            (lines[i].startsWith('> ') || lines[i] == '>')) {
          quoteLines.add(
            lines[i].startsWith('> ') ? lines[i].substring(2) : '',
          );
          i++;
        }
        blocks.add(_QuoteBlock(text: quoteLines.join('\n')));
        continue;
      }

      // 4. Bullet lists (- or *)
      final bulletMatch = RegExp(r'^(\*|-)\s+(.*)$').firstMatch(line);
      if (bulletMatch != null) {
        blocks.add(
          _ListItemBlock(prefix: '• ', text: bulletMatch.group(2)!),
        );
        i++;
        continue;
      }

      // 5. Numbered lists (1. ...)
      final numMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(line);
      if (numMatch != null) {
        final numPrefix = '${numMatch.group(1)!}. ';
        blocks.add(
          _ListItemBlock(prefix: numPrefix, text: numMatch.group(2)!),
        );
        i++;
        continue;
      }

      // 6. Regular Paragraph Line(s)
      final List<String> paraLines = [line];
      i++;
      while (i < lines.length &&
          !lines[i].trimLeft().startsWith('```') &&
          !RegExp(r'^(#{1,3})\s+').hasMatch(lines[i]) &&
          !lines[i].startsWith('> ') &&
          !RegExp(r'^(\*|-)\s+').hasMatch(lines[i]) &&
          !RegExp(r'^(\d+)\.\s+').hasMatch(lines[i])) {
        paraLines.add(lines[i]);
        i++;
      }
      blocks.add(_ParagraphBlock(text: paraLines.join('\n')));
    }

    return blocks;
  }
}

// --- Block Definitions ---

sealed class _Block {}

class _ParagraphBlock extends _Block {
  final String text;
  _ParagraphBlock({required this.text});
}

class _HeaderBlock extends _Block {
  final int level;
  final String text;
  _HeaderBlock({required this.level, required this.text});
}

class _QuoteBlock extends _Block {
  final String text;
  _QuoteBlock({required this.text});
}

class _ListItemBlock extends _Block {
  final String prefix;
  final String text;
  _ListItemBlock({required this.prefix, required this.text});
}

class _CodeBlock extends _Block {
  final String language;
  final String code;
  _CodeBlock({required this.language, required this.code});
}
