import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/custom_emoji.dart';
import '../../../../core/theme/wk.dart';
import '../../../../core/theme/wiltkey_tokens.dart';

/// A compact emoji picker shown in place of the keyboard. A tap inserts the
/// standard unicode emoji at the cursor (or the chat's custom `:name:` token);
/// a long-press fires [onSendSticker] to send it immediately as a big,
/// bubble-less sticker. Stateless about visibility — the parent shows/hides it.
class EmojiPickerPanel extends StatefulWidget {
  final TextEditingController controller;

  /// The chat's live custom-emoji pool (name -> emoji); shown as a first tab.
  final Map<String, CustomEmoji> emojiMap;
  final double height;

  /// Long-press handler: sends the given emoji/`:name:` payload as a sticker.
  /// When null, long-press does nothing (sticker sending disabled).
  final void Function(String payload)? onSendSticker;

  const EmojiPickerPanel({
    super.key,
    required this.controller,
    this.emojiMap = const {},
    this.height = 252,
    this.onSendSticker,
  });

  // Curated unicode sets — enough for everyday use without bundling a full DB.
  static const List<String> _smileys = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '😂',
    '🤣',
    '🙂',
    '🙃',
    '😉',
    '😊',
    '😇',
    '🥰',
    '😍',
    '😘',
    '😗',
    '😋',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🤑',
    '🤗',
    '🤭',
    '🤫',
    '🤔',
    '🤐',
    '😐',
    '😑',
    '😶',
    '😏',
    '😒',
    '🙄',
    '😬',
    '😌',
    '😔',
    '😪',
    '😴',
    '😷',
    '🤒',
    '🤕',
    '🤢',
    '🤮',
    '🥵',
    '🥶',
    '🥴',
    '😵',
    '🤯',
    '🤠',
    '🥳',
    '😎',
    '🤓',
    '🧐',
    '😕',
    '😟',
    '🙁',
    '☹️',
    '😮',
    '😲',
    '😳',
    '🥺',
    '😦',
    '😨',
    '😰',
    '😥',
    '😢',
    '😭',
    '😱',
    '😖',
    '😣',
    '😞',
    '😓',
    '😩',
    '😫',
    '🥱',
    '😤',
    '😡',
    '😠',
    '🤬',
  ];
  static const List<String> _gestures = [
    '👍',
    '👎',
    '👌',
    '🤌',
    '🤏',
    '✌️',
    '🤞',
    '🤟',
    '🤘',
    '🤙',
    '👈',
    '👉',
    '👆',
    '👇',
    '☝️',
    '✋',
    '🤚',
    '🖐️',
    '🖖',
    '👋',
    '🤝',
    '🙏',
    '💪',
    '🦾',
    '👏',
    '🙌',
    '👐',
    '🤲',
    '🫶',
    '🤜',
    '🤛',
    '✊',
    '👊',
    '🫵',
    '👀',
    '👁️',
    '🧠',
    '🫀',
    '👅',
    '👄',
    '🦴',
    '🦷',
    '👂',
    '👃',
    '🫦',
    '🤳',
    '💅',
    '🦵',
  ];
  static const List<String> _hearts = [
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '🤎',
    '💔',
    '❣️',
    '💕',
    '💞',
    '💓',
    '💗',
    '💖',
    '💘',
    '💝',
    '💟',
    '💌',
    '💋',
    '✨',
    '⭐',
    '🌟',
    '💫',
    '⚡',
    '🔥',
    '💥',
    '💯',
    '✅',
    '❌',
    '⭕',
    '❗',
    '❓',
    '‼️',
    '⁉️',
    '💤',
    '🎉',
    '🎊',
    '🎁',
    '🏆',
    '🥇',
    '🌈',
    '☀️',
    '🌙',
    '⛅',
    '☔',
    '❄️',
  ];
  static const List<String> _animals = [
    '🐶',
    '🐱',
    '🐭',
    '🐹',
    '🐰',
    '🦊',
    '🐻',
    '🐼',
    '🐨',
    '🐯',
    '🦁',
    '🐮',
    '🐷',
    '🐸',
    '🐵',
    '🙈',
    '🙉',
    '🙊',
    '🐔',
    '🐧',
    '🐦',
    '🦆',
    '🦉',
    '🦄',
    '🐝',
    '🦋',
    '🐌',
    '🐞',
    '🐢',
    '🐍',
    '🐙',
    '🦀',
    '🐳',
    '🐬',
    '🐟',
    '🦓',
    '🦒',
    '🐘',
    '🐪',
    '🌸',
    '🌺',
    '🌻',
    '🌹',
    '🌷',
    '🌼',
    '🌲',
    '🌴',
    '🍀',
  ];
  static const List<String> _food = [
    '🍎',
    '🍐',
    '🍊',
    '🍋',
    '🍌',
    '🍉',
    '🍇',
    '🍓',
    '🫐',
    '🍒',
    '🍑',
    '🥭',
    '🍍',
    '🥥',
    '🥝',
    '🍅',
    '🥑',
    '🌽',
    '🥕',
    '🍔',
    '🍟',
    '🍕',
    '🌭',
    '🥪',
    '🌮',
    '🌯',
    '🥗',
    '🍝',
    '🍜',
    '🍣',
    '🍱',
    '🍤',
    '🍙',
    '🍚',
    '🍦',
    '🍰',
    '🎂',
    '🧁',
    '🍩',
    '🍪',
    '🍫',
    '🍬',
    '🍭',
    '🍿',
    '☕',
    '🍵',
    '🍺',
    '🍷',
  ];
  static const List<String> _activities = [
    '⚽',
    '🏀',
    '🏈',
    '⚾',
    '🎾',
    '🏐',
    '🎱',
    '🏓',
    '🏸',
    '🥅',
    '⛳',
    '🎮',
    '🕹️',
    '🎲',
    '🎯',
    '🎸',
    '🎺',
    '🎻',
    '🥁',
    '🎤',
    '🎧',
    '🎬',
    '🎨',
    '♟️',
    '🚗',
    '🚕',
    '🚙',
    '🚌',
    '🏎️',
    '🚓',
    '✈️',
    '🚀',
    '🚲',
    '🛵',
    '🏠',
    '🏖️',
    '🗻',
    '🗼',
    '🎆',
    '🎇',
    '🧭',
    '⏰',
    '💡',
    '🔋',
    '📱',
    '💻',
    '📷',
    '🔒',
  ];

  @override
  State<EmojiPickerPanel> createState() => _EmojiPickerPanelState();
}

class _EmojiPickerPanelState extends State<EmojiPickerPanel> {
  /// Long-press → send as a sticker. A light haptic confirms the gesture so the
  /// user can tell it apart from a tap-insert.
  void _sticker(String payload) {
    final cb = widget.onSendSticker;
    if (cb == null) return;
    HapticFeedback.selectionClick();
    cb(payload);
  }

  void _insert(String text) {
    final c = widget.controller;
    final sel = c.selection;
    final base = c.text;
    if (sel.isValid && sel.start >= 0 && sel.end >= sel.start) {
      final newText = base.replaceRange(sel.start, sel.end, text);
      c.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start + text.length),
      );
    } else {
      final newText = base + text;
      c.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final custom = widget.emojiMap.values.where((e) => !e.deleted).toList();
    final hasCustom = custom.isNotEmpty;

    final tabs = <Widget>[
      if (hasCustom) const Tab(icon: Icon(Icons.star_outline, size: 20)),
      const Tab(icon: Icon(Icons.emoji_emotions_outlined, size: 20)),
      const Tab(icon: Icon(Icons.back_hand_outlined, size: 20)),
      const Tab(icon: Icon(Icons.favorite_border, size: 20)),
      const Tab(icon: Icon(Icons.pets_outlined, size: 20)),
      const Tab(icon: Icon(Icons.restaurant_outlined, size: 20)),
      const Tab(icon: Icon(Icons.sports_esports_outlined, size: 20)),
    ];

    final views = <Widget>[
      if (hasCustom) _customGrid(t, custom),
      _emojiGrid(EmojiPickerPanel._smileys),
      _emojiGrid(EmojiPickerPanel._gestures),
      _emojiGrid(EmojiPickerPanel._hearts),
      _emojiGrid(EmojiPickerPanel._animals),
      _emojiGrid(EmojiPickerPanel._food),
      _emojiGrid(EmojiPickerPanel._activities),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(
            top: BorderSide(color: t.border, width: t.borderWidth),
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                indicatorColor: t.action,
                labelColor: t.action,
                unselectedLabelColor: t.textTertiary,
                dividerColor: t.border,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                tabs: tabs,
              ),
            ),
            Expanded(child: TabBarView(children: views)),
            if (widget.onSendSticker != null) _stickerHint(t, context),
          ],
        ),
      ),
    );
  }

  /// Thin footer hint telling the user that a long-press sends a big sticker.
  Widget _stickerHint(WiltkeyTokens t, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.border, width: t.borderWidth)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_outlined, size: 12, color: t.textTertiary),
          const SizedBox(width: 5),
          Text(
            t.uppercaseLabels
                ? l10n.chatStickerHint.toUpperCase()
                : l10n.chatStickerHint,
            style: t.dataMono.copyWith(color: t.textTertiary, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  Widget _emojiGrid(List<String> emojis) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 44,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, i) {
        final e = emojis[i];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _insert(e),
          onLongPress:
              widget.onSendSticker == null ? null : () => _sticker(e),
          child: Center(child: Text(e, style: const TextStyle(fontSize: 24))),
        );
      },
    );
  }

  Widget _customGrid(WiltkeyTokens t, List<CustomEmoji> custom) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 48,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: custom.length,
      itemBuilder: (context, i) {
        final e = custom[i];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _insert(e.token),
          onLongPress:
              widget.onSendSticker == null ? null : () => _sticker(e.token),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Image.memory(
              e.bytes,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => Text(e.token, style: t.dataMono),
            ),
          ),
        );
      },
    );
  }
}
