import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/theme/wk.dart';

/// Top search bar widget attached under the chat screen app bar for in-memory keyword search.
class ChatSearchBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController controller;
  final int matchCount;
  final int currentMatchIndex; // 0-indexed
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;
  final ValueChanged<String> onChanged;

  const ChatSearchBar({
    super.key,
    required this.controller,
    required this.matchCount,
    required this.currentMatchIndex,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
    required this.onChanged,
  });

  @override
  Size get preferredSize => const Size.fromHeight(54);

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;

    final String counterText = matchCount == 0
        ? (l10n.chatSearchNoMatches ?? '0 matches')
        : '${currentMatchIndex + 1} of $matchCount';

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(
          bottom: BorderSide(color: t.border, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: t.action),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              style: t.body.copyWith(fontSize: 14),
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: l10n.chatSearchHint ?? 'Search in chat...',
                hintStyle: t.bodySecondary.copyWith(fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          if (controller.text.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: t.bg,
                borderRadius: BorderRadius.circular(t.radiusPill),
                border: Border.all(color: t.border),
              ),
              child: Text(
                counterText,
                style: t.dataMono.copyWith(fontSize: 10, color: t.textSecondary),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.keyboard_arrow_up, size: 20, color: matchCount > 0 ? t.action : t.textTertiary),
              onPressed: matchCount > 0 ? onPrevious : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: Icon(Icons.keyboard_arrow_down, size: 20, color: matchCount > 0 ? t.action : t.textTertiary),
              onPressed: matchCount > 0 ? onNext : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
          IconButton(
            icon: Icon(Icons.close, size: 20, color: t.textSecondary),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
