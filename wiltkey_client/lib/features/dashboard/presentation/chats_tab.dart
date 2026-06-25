import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/models.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/custom_widgets.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../../core/theme/wiltkey_components.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../chat/presentation/group_chat_screen.dart';
import '../../chat/presentation/widgets/nuke_confirm_dialog.dart';
import '../../groups/presentation/create_group_screen.dart';
import '../../groups/presentation/group_search_screen.dart';
import '../../shell/presentation/app_shell.dart';

/// The Chats tab: a single list of every conversation — 1:1 contacts and groups
/// merged, groups badged. Header carries the title, search, debug console and a
/// "+" menu for group create/join. (Replaces the old Dashboard CHATS/GROUPS
/// tabs + bottom "SYNC" button; pairing is now its own tab.)
class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  final AppState _appState = AppState();
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _ChatFilter _filter = _ChatFilter.all;

  /// Recency used for ordering: the latest message timestamp if there is one,
  /// else the contact's pairing time. (lastActivity isn't bumped per-message, so
  /// we look at the message log for true conversation recency.)
  DateTime _effectiveActivity(Contact c) {
    final msgs = _appState.messages[c.id];
    if (msgs != null && msgs.isNotEmpty) {
      final last = msgs.last.timestamp;
      return last.isAfter(c.lastActivity) ? last : c.lastActivity;
    }
    return c.lastActivity;
  }

  bool _matchesFilter(Contact c) {
    switch (_filter) {
      case _ChatFilter.all:
        return true;
      case _ChatFilter.direct:
        return !c.isGroup;
      case _ChatFilter.groups:
        return c.isGroup;
    }
  }

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onState);
  }

  @override
  void dispose() {
    _appState.removeListener(_onState);
    _searchController.dispose();
    super.dispose();
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  void _openContact(Contact c) {
    _appState.selectContact(c);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            c.isGroup ? const GroupChatScreen() : const ChatScreen(),
      ),
    );
  }

  /// Long-press actions on a chat row. Live chats can be archived (drop the OTP
  /// pad, keep messages read-only) or nuked (wipe everything + tell the peer).
  /// Already-archived chats can only be deleted locally.
  void _showChatActions(Contact c) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    c.name,
                    style: t.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (!c.isArchived)
                ListTile(
                  leading: Icon(
                    c.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: t.action,
                  ),
                  title: Text(
                    c.isPinned ? l10n.chatsActionUnpin : l10n.chatsActionPin,
                    style: t.body,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _appState.togglePin(c.keyHash);
                  },
                ),
              if (!c.isArchived)
                ListTile(
                  leading: Icon(Icons.inventory_2_outlined, color: t.action),
                  title: Text(l10n.chatsActionArchive, style: t.body),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmArchive(c);
                  },
                ),
              ListTile(
                leading: Icon(
                  c.isArchived
                      ? Icons.delete_outline
                      : Icons.local_fire_department_outlined,
                  color: t.danger,
                ),
                title: Text(
                  c.isArchived ? l10n.chatsActionDelete : l10n.chatsActionNuke,
                  style: t.body.copyWith(color: t.danger),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (c.isArchived) {
                    NukeConfirmDialog.show(
                      context,
                      () => _appState.deleteChatLocally(c.keyHash),
                    );
                  } else {
                    NukeConfirmDialog.show(
                      context,
                      () => _appState.nukeContact(
                        c.keyHash,
                        receivedFromPeer: false,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmArchive(Contact c) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.border, width: t.borderWidth),
        ),
        title: Text(
          l10n.chatsArchiveConfirmTitle,
          style: t.screenTitle.copyWith(fontSize: 16),
        ),
        content: Text(
          l10n.chatsArchiveConfirmBody,
          style: t.bodySecondary.copyWith(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              l10n.commonCancel,
              style: TextStyle(color: t.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _appState.archiveChat(c.keyHash);
            },
            child: Text(l10n.chatsArchiveConfirmButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final all = _appState.contacts;
    final lockedCount = all.where((c) => c.isWilted).length;
    final subtitle = l10n.chatsSubtitle(all.length, lockedCount);

    // Apply search + type filter, then split into pinned / regular / archived,
    // each newest-first. Pinned floats to the top; archived sinks to its own
    // section at the bottom.
    final q = _query.toLowerCase();
    final visible = all
        .where(
          (c) =>
              _matchesFilter(c) &&
              (q.isEmpty || c.name.toLowerCase().contains(q)),
        )
        .toList();
    int byRecency(Contact a, Contact b) =>
        _effectiveActivity(b).compareTo(_effectiveActivity(a));
    final pinned = visible.where((c) => c.isPinned && !c.isArchived).toList()
      ..sort(byRecency);
    final regular = visible.where((c) => !c.isPinned && !c.isArchived).toList()
      ..sort(byRecency);
    final archived = visible.where((c) => c.isArchived).toList()
      ..sort(byRecency);

    final entries = <Object>[
      ...pinned,
      ...regular,
      if (archived.isNotEmpty) ...[
        _SectionHeader(l10n.chatsSectionArchived),
        ...archived,
      ],
    ];

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: context.wkc.screenTitle(
                  context,
                  l10n.chatsTitle,
                  subtitle: subtitle,
                ),
              ),
              if (_appState.showDebugButtons)
                IconButton(
                  icon: Icon(
                    Icons.terminal_outlined,
                    color: t.action,
                    size: 20,
                  ),
                  tooltip: l10n.settingsDebugTitle,
                  onPressed: () => showDebugConsole(context),
                ),
              PopupMenuButton<String>(
                icon: Icon(Icons.add, color: t.action, size: 22),
                color: t.surface,
                tooltip: 'New',
                onSelected: (v) {
                  if (v == 'create') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CreateGroupScreen()),
                    );
                  } else if (v == 'join') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GroupSearchScreen(),
                      ),
                    );
                  } else if (v == 'pair') {
                    AppShell.of(context).selectTab(ShellTab.pair);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pair',
                    child: Text(l10n.chatsPopupPair, style: t.body),
                  ),
                  PopupMenuItem(
                    value: 'create',
                    child: Text(l10n.chatsPopupCreateGroup, style: t.body),
                  ),
                  PopupMenuItem(
                    value: 'join',
                    child: Text(l10n.chatsPopupJoinGroup, style: t.body),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            controller: _searchController,
            style: t.body,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.chatsSearchHint,
              hintStyle: t.body.copyWith(color: t.textTertiary),
              prefixIcon: Icon(Icons.search, color: t.textTertiary, size: 18),
              filled: true,
              fillColor: t.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.radiusControl),
                borderSide: BorderSide(color: t.border, width: t.borderWidth),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.radiusControl),
                borderSide: BorderSide(color: t.action, width: t.borderWidth),
              ),
            ),
          ),
        ),

        // Type filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              _filterChip(t, l10n.chatsFilterAll, _ChatFilter.all),
              const SizedBox(width: 8),
              _filterChip(t, l10n.chatsFilterDirect, _ChatFilter.direct),
              const SizedBox(width: 8),
              _filterChip(t, l10n.chatsFilterGroups, _ChatFilter.groups),
            ],
          ),
        ),

        // List
        Expanded(
          child: entries.isEmpty
              ? _EmptyState(hasContacts: all.isNotEmpty)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final entry = entries[i];
                    if (entry is _SectionHeader) {
                      return _sectionHeader(t, entry.label);
                    }
                    final c = entry as Contact;
                    return _EntranceItem(
                      key: ValueKey(c.id),
                      index: i,
                      child: _ContactRow(
                        contact: c,
                        myId: _appState.userId,
                        onTap: () => _openContact(c),
                        onLongPress: () => _showChatActions(c),
                        onSync: () =>
                            AppShell.of(context).selectTab(ShellTab.pair),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterChip(WiltkeyTokens t, String label, _ChatFilter value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? t.action.withValues(alpha: 0.15) : t.surface,
          border: Border.all(
            color: selected ? t.action : t.border,
            width: t.borderWidth,
          ),
          borderRadius: BorderRadius.circular(t.radiusPill),
        ),
        child: Text(
          t.uppercaseLabels ? label.toUpperCase() : label,
          style: t.badgeLabel.copyWith(
            color: selected ? t.action : t.textSecondary,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(WiltkeyTokens t, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
      child: Row(
        children: [
          Text(
            t.uppercaseLabels ? label.toUpperCase() : label,
            style: t.sectionLabel.copyWith(color: t.textTertiary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: t.border, height: 1)),
        ],
      ),
    );
  }
}

/// Type filter for the chats list.
enum _ChatFilter { all, direct, groups }

/// A non-contact entry in the list (a labelled divider, e.g. "Archived").
class _SectionHeader {
  final String label;
  const _SectionHeader(this.label);
}

class _ContactRow extends StatelessWidget {
  final Contact contact;
  final String myId;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSync;

  const _ContactRow({
    required this.contact,
    required this.myId,
    required this.onTap,
    required this.onLongPress,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final c = contact;

    // Budget: groups report USABLE budget (own lane + claimable lanes); 1:1 uses
    // the raw remaining. This keeps the group flower from collapsing to one petal
    // against the huge shared pad.
    final group = c.isGroup ? AppState().groupBudget(c) : null;
    final double ourFraction = group?.fraction ?? c.chargePercentage;
    final bool wilted = group != null ? group.fraction <= 0 : c.isWilted;
    final remaining = AppState.formatBytes(
      group?.usableRemaining ?? c.remainingBufferBytes,
    );
    final maxF = AppState.formatBytes(
      group?.usableCapacity ?? c.maxBufferBytes,
    );

    // Unread count drives the badge; archived chats are read-only (never unread).
    final int unread = c.isArchived ? 0 : AppState().unreadCount(c);

    final l10n = AppLocalizations.of(context)!;
    final String subtitle;
    if (c.isArchived) {
      subtitle = l10n.chatsArchivedSubtitle;
    } else if (c.isWilted) {
      subtitle = l10n.chatsLockedSubtitle;
    } else if (c.isGroup) {
      subtitle = l10n.chatsMemberCount(c.memberCount ?? 1);
    } else {
      subtitle = Uri.tryParse(c.relayUrl)?.host ?? c.relayUrl;
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: wilted ? Colors.transparent : t.surface,
          border: Border.all(
            color: wilted ? t.budgetWilted.withValues(alpha: 0.4) : t.border,
            width: t.borderWidth,
          ),
          borderRadius: BorderRadius.circular(t.radiusCard),
        ),
        child: Row(
          children: [
            PixelArtAvatar(hexString: _avatarHex(c), size: 44),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (c.isArchived) ...[
                        const SizedBox(width: 8),
                        context.wkc.statusBadge(
                          context,
                          StatusBadgeKind.archived,
                        ),
                      ] else if (c.isGroup) ...[
                        const SizedBox(width: 8),
                        context.wkc.statusBadge(context, StatusBadgeKind.group),
                      ] else if (c.isPrivateNode) ...[
                        const SizedBox(width: 8),
                        const PrivateNodeBadge(),
                      ],
                      if (c.isPinned && !c.isArchived) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.push_pin, size: 13, color: t.textTertiary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySecondary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.isGroup
                        ? l10n.chatsRowGroupRemaining(remaining, maxF)
                        : l10n.chatsRowMeRemaining(
                            remaining,
                            AppState.formatBytes(
                              c.getTheirRemainingBytes(myId),
                            ),
                          ),
                    style: t.dataMono.copyWith(
                      color: wilted ? t.action : t.positive,
                    ),
                  ),
                ],
              ),
            ),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.action,
                  borderRadius: BorderRadius.circular(t.radiusPill),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: t.dataMono.copyWith(
                    color: t.onAction,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 10),
            // Budget glyph. 1:1 uses the (theme-specific) split indicator; groups
            // show their usable budget (own lane + claimable lanes) as our-fraction.
            context.wkc.budgetIndicator(
              ourFraction: ourFraction,
              theirFraction: c.isGroup ? 0 : c.getTheirChargePercentage(myId),
              isWilted: wilted,
              split: !c.isGroup,
              variant: BudgetIndicatorVariant.listRow,
              semanticLabel: '$remaining remaining',
            ),
          ],
        ),
      ),
    );
  }

  String _avatarHex(Contact c) {
    if (c.isGroup && c.groupIconHex != null && c.groupIconHex!.isNotEmpty) {
      return c.groupIconHex!;
    }
    if (c.profileImageB64 != null && c.profileImageB64!.isNotEmpty) {
      return c.profileImageB64!;
    }
    return PixelArtAvatar.generateIdenticon(c.keyHash);
  }
}

/// Plays a one-shot fade/slide-up when a row first appears. State persists
/// across rebuilds (keyed by contact id) so it animates once, not on every
/// AppState change.
class _EntranceItem extends StatefulWidget {
  final int index;
  final Widget child;
  const _EntranceItem({super.key, required this.index, required this.child});

  @override
  State<_EntranceItem> createState() => _EntranceItemState();
}

class _EntranceItemState extends State<_EntranceItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  @override
  void initState() {
    super.initState();
    // Honor reduce-motion lazily (need context); default to playing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.reduceMotion) {
        _c.value = 1.0;
      } else {
        Future.delayed(Duration(milliseconds: 40 * widget.index), () {
          if (mounted) _c.forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = Curves.easeOut.transform(_c.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - v)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasContacts;
  const _EmptyState({required this.hasContacts});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    if (hasContacts) {
      return Center(
        child: Text(l10n.chatsEmptyNoMatches, style: t.bodySecondary),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(t.emptyChatsIcon, color: t.textTertiary, size: 44),
            const SizedBox(height: 14),
            Text(
              l10n.chatsEmptyNoChats,
              style: t.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.chatsEmptyPairInstruction,
              style: t.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => AppShell.of(context).selectTab(ShellTab.pair),
              icon: const Icon(Icons.adjust, size: 16),
              label: Text(l10n.chatsEmptyPairButton),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet debug console (moved from the old dashboard; tokenized).
void showDebugConsole(BuildContext context) {
  final t = context.wk;
  final l10n = AppLocalizations.of(context)!;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.bg,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.terminal, color: t.action, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          t.uppercaseLabels
                              ? l10n.settingsDebugTitle.toUpperCase()
                              : l10n.settingsDebugTitle,
                          style: t.screenTitle.copyWith(fontSize: 15),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: t.danger,
                            size: 20,
                          ),
                          onPressed: () =>
                              setModalState(() => AppState.debugLogs.clear()),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: t.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(color: t.border),
                Expanded(
                  child: ListenableBuilder(
                    listenable: AppState.logRevision,
                    builder: (context, _) {
                      return ListView.builder(
                        itemCount: AppState.debugLogs.length,
                        reverse: true,
                        itemBuilder: (context, index) {
                          final logItem = AppState
                              .debugLogs[AppState.debugLogs.length - 1 - index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              logItem,
                              style: t.dataMono.copyWith(
                                color: t.positive,
                                fontSize: 10.5,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
