import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../chat/presentation/widgets/emoji_picker_panel.dart';
import '../../../core/theme/wk.dart';

/// Shows a bottom sheet allowing the user to select an emoji for their status.
/// Returns the selected emoji String, or `''` if cleared, or `null` if cancelled.
Future<String?> showStatusEmojiPickerSheet(
  BuildContext context, {
  String? currentEmoji,
}) {
  final t = context.wk;

  final categories = EmojiPickerPanel.categories;
  const categoryIcons = [
    Icons.emoji_emotions_outlined,
    Icons.back_hand_outlined,
    Icons.favorite_border,
    Icons.pets_outlined,
    Icons.restaurant_outlined,
    Icons.sports_esports_outlined,
  ];

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: t.surface,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
      side: BorderSide(color: t.border, width: t.borderWidth),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.55,
          child: DefaultTabController(
            length: categories.length,
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Choose Status Emoji',
                        style: t.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (currentEmoji != null && currentEmoji.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(sheetContext, '');
                          },
                          child: Text(
                            'Remove',
                            style: t.badgeLabel.copyWith(color: t.danger),
                          ),
                        ),
                    ],
                  ),
                ),
                // Tab bar
                SizedBox(
                  height: 40,
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    indicatorColor: t.action,
                    labelColor: t.action,
                    unselectedLabelColor: t.textSecondary,
                    tabs: [
                      for (int i = 0; i < categories.length; i++)
                        Tab(
                          icon: Icon(
                            i < categoryIcons.length
                                ? categoryIcons[i]
                                : Icons.emoji_emotions_outlined,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
                Divider(height: 1, color: t.border, thickness: t.borderWidth),
                // Tab views
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final cat in categories)
                        GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 52,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                              ),
                          itemCount: cat.length,
                          itemBuilder: (ctx, idx) {
                            final emoji = cat[idx];
                            final isSelected = emoji == currentEmoji;
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.pop(sheetContext, emoji);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? t.action.withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    t.radiusControl,
                                  ),
                                  border: isSelected
                                      ? Border.all(
                                          color: t.action,
                                          width: t.borderWidth,
                                        )
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
