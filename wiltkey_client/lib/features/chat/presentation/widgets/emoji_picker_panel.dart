import 'package:flutter/material.dart';
import '../../../../core/custom_emoji.dart';
import '../../../../core/theme/wk.dart';
import '../../../../core/theme/wiltkey_tokens.dart';

/// A compact emoji picker shown in place of the keyboard. Inserts standard
/// unicode emoji at the cursor, and the chat's custom `:name:` emoji as tokens.
/// Stateless about visibility — the parent composer shows/hides it.
class EmojiPickerPanel extends StatefulWidget {
  final TextEditingController controller;

  /// The chat's live custom-emoji pool (name -> emoji); shown as a first tab.
  final Map<String, CustomEmoji> emojiMap;
  final double height;

  const EmojiPickerPanel({
    super.key,
    required this.controller,
    this.emojiMap = const {},
    this.height = 252,
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
          ],
        ),
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
