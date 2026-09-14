import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/models.dart';
import '../../../core/pixel_art_avatar.dart';
import '../../../core/custom_widgets.dart';
import '../../../core/debug_clipboard.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../../core/theme/wiltkey_components.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../chat/presentation/group_chat_screen.dart';
import 'events_screen.dart';
import '../../chat/presentation/widgets/nuke_confirm_dialog.dart';
import '../../proximity/presentation/pairing_screen.dart';
import '../../shell/presentation/app_shell.dart';
import '../../../core/theme/widgets/client_integrity_badge.dart';
import '../../stories/presentation/stories_bar.dart';

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

  // Swipe from left to right anywhere to open Contacts panel (no edge gate)
  static const double _swipeDistanceThreshold = 120.0; // minimum drag distance
  static const double _swipeVelocityThreshold = 800.0; // px/s
  double _dragStartX = 0;
  bool _dragStarted = false;

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

  // Ticks the Time Wilt countdowns on the list. Only rebuilds when some chat is
  // in its final-minutes window (mirrors the chat screen's cadence — no point
  // re-rendering the whole list every second when everything is hours away), and
  // sweeps any chat that just crossed its expiry so it flips to archived here.
  Timer? _wiltTicker;

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onState);
    _appState.refreshStoriesFeed();
    _wiltTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      bool needsSweep = false;
      bool ticking = false;
      for (final c in _appState.contacts) {
        if (!c.isTimeWilt || c.isArchived) continue;
        final exp = c.wiltExpiresAt;
        if (exp == null) continue;
        final left = exp.difference(now);
        if (left.inSeconds <= 0) {
          needsSweep = true;
        } else if (left.inMinutes < 10) {
          ticking = true;
        }
      }
      if (needsSweep) {
        _appState.sweepTimeWiltChats(); // notifies → _onState rebuilds
      } else if (ticking) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _wiltTicker?.cancel();
    _appState.removeListener(_onState);
    _searchController.dispose();
    super.dispose();
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  void _onDragStart(DragStartDetails details) {
    _dragStartX = details.localPosition.dx;
    _dragStarted = true;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragStarted) return;
    final dx = details.localPosition.dx - _dragStartX;
    if (dx >= _swipeDistanceThreshold) {
      _openContactsPanel();
      _dragStarted = false; // fire once
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragStarted) return;
    final dx = details.localPosition.dx - _dragStartX;
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (dx >= _swipeDistanceThreshold || velocity > _swipeVelocityThreshold) {
      _openContactsPanel();
    }
    _dragStarted = false;
  }

  void _onDragCancel() {
    _dragStarted = false;
  }

  void _openContactsPanel() {
    if (!mounted) return;
    AppShell.of(context).selectTab(ShellTab.contacts);
  }

  void _openContact(Contact c) {
    if (c.isPendingEmergency) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: context.wk.surface,
          content: Text(
            l10n.chatsEmergencyPendingSnackBar(c.name),
            style: context.wk.bodySecondary.copyWith(color: context.wk.warning),
          ),
        ),
      );
      return;
    }
    _appState.selectContact(c);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            c.isGroup ? const GroupChatScreen() : const ChatScreen(),
      ),
    ).then((_) => _appState.clearVisibleChatIfCurrent(c.id));
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
              if (c.isPendingEmergency) ...[
                ListTile(
                  leading: Icon(Icons.delete_outline, color: t.danger),
                  title: Text(
                    l10n.chatsActionDelete,
                    style: t.body.copyWith(color: t.danger),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    NukeConfirmDialog.show(
                      context,
                      () => _appState.deleteChatLocally(c.keyHash),
                    );
                  },
                ),
              ] else ...[
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
                    leading: Icon(
                      c.isMuted
                          ? Icons.notifications_off_outlined
                          : (c.isMentionsOnly
                              ? Icons.alternate_email
                              : Icons.notifications_outlined),
                      color: t.action,
                    ),
                    title: Text(
                      c.isGroup
                          ? l10n.chatNotificationSettingsTitle
                          : (c.isMuted ? l10n.chatUnmuteTitle : l10n.chatMuteTitle),
                      style: t.body,
                    ),
                    subtitle: c.isGroup
                        ? Text(
                            c.isMuted
                                ? l10n.chatNotificationModeMuted
                                : (c.isMentionsOnly
                                    ? l10n.chatNotificationModeMentions
                                    : l10n.chatNotificationModeAll),
                            style: t.bodySecondary.copyWith(fontSize: 12),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      if (c.isGroup) {
                        _showGroupNotificationSettingsSheet(c);
                      } else {
                        _appState.setChatNotificationMode(
                          c,
                          c.isMuted ? 'all' : 'muted',
                        );
                      }
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
                    } else if (c.isGroup) {
                      // Groups must go through the majority-vote proposal —
                      // the plain local wipe here used to silently bypass the
                      // vote (destroyed the local copy of ANY group, no
                      // consensus needed). Solo/2-member groups still execute
                      // immediately inside proposeGroupNuke.
                      NukeConfirmDialog.show(
                        context,
                        () => _appState.proposeGroupNuke(c),
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
            ],
          ),
        );
      },
    );
  }

  void _showGroupNotificationSettingsSheet(Contact group) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final currentMode = group.notificationMode;

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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.notifications_outlined, color: t.action, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      l10n.chatNotificationSettingsTitle,
                      style: t.screenTitle.copyWith(fontSize: 16),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(
                  currentMode == 'all'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: currentMode == 'all' ? t.action : t.textTertiary,
                ),
                title: Text(l10n.chatNotificationModeAll, style: t.body),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _appState.setChatNotificationMode(group, 'all');
                },
              ),
              ListTile(
                leading: Icon(
                  currentMode == 'mentions_only'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color:
                      currentMode == 'mentions_only' ? t.action : t.textTertiary,
                ),
                title: Text(l10n.chatNotificationModeMentions, style: t.body),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _appState.setChatNotificationMode(group, 'mentions_only');
                },
              ),
              ListTile(
                leading: Icon(
                  currentMode == 'muted'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: currentMode == 'muted' ? t.danger : t.textTertiary,
                ),
                title: Text(
                  l10n.chatNotificationModeMuted,
                  style: t.body.copyWith(
                    color: currentMode == 'muted' ? t.danger : null,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _appState.setChatNotificationMode(group, 'muted');
                },
              ),
              const SizedBox(height: 8),
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
              (q.isEmpty ||
                  c.displayName.toLowerCase().contains(q) ||
                  c.name.toLowerCase().contains(q)),
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

    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: _onDragCancel,
      behavior: HitTestBehavior.translucent,
      child: Column(
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
              // Activity feed. Replaced the old "+" (create/join/pair) menu —
              // the Connect tab now owns all of those. A dot badges unread events.
              _ActivityBell(
                unread: _appState.unreadEventCount,
                color: t.action,
                badgeColor: t.danger,
                tooltip: l10n.activityTitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EventsScreen()),
                ),
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

        // 24-hour Wilting Stories Reel (gated by social account and stories settings)
        if (_appState.socialAccountEnabled && _appState.storiesEnabled)
          const StoriesBar(),

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
                    final rightAct = _appState.swipeRightAction;
                    final leftAct = _appState.swipeLeftAction;
                    final hasRight = rightAct != 'none';
                    final hasLeft = leftAct != 'none';
                    final direction = (hasRight && hasLeft)
                        ? DismissDirection.horizontal
                        : (hasRight
                            ? DismissDirection.startToEnd
                            : (hasLeft
                                ? DismissDirection.endToStart
                                : DismissDirection.none));

                    Widget row = _ContactRow(
                      contact: c,
                      myId: _appState.userId,
                      onTap: () => _openContact(c),
                      onLongPress: () => _showChatActions(c),
                      // Recharge is a known target — skip the hub menu and go
                      // straight into the in-person pairing flow.
                      onSync: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PairingScreen(),
                        ),
                      ),
                    );

                    if (direction != DismissDirection.none) {
                      row = Dismissible(
                        key: ValueKey(
                          'swipe_${c.id}_${c.isPinned}_${c.isMuted}_${_appState.unreadCount(c)}',
                        ),
                        direction: direction,
                        background: _buildSwipeBackground(
                          context: context,
                          contact: c,
                          action: rightAct,
                          isRightSwipe: true,
                        ),
                        secondaryBackground: _buildSwipeBackground(
                          context: context,
                          contact: c,
                          action: leftAct,
                          isRightSwipe: false,
                        ),
                        confirmDismiss: (dismissDir) async {
                          if (dismissDir == DismissDirection.startToEnd) {
                            _executeSwipeAction(rightAct, c);
                          } else if (dismissDir == DismissDirection.endToStart) {
                            _executeSwipeAction(leftAct, c);
                          }
                          return false; // Snap back cleanly
                        },
                        child: row,
                      );
                    }

                    return _EntranceItem(
                      key: ValueKey(c.id),
                      index: i,
                      child: row,
                    );
                  },
                ),
        ),
      ],
    ));
  }

  Widget? _buildSwipeBackground({
    required BuildContext context,
    required Contact contact,
    required String action,
    required bool isRightSwipe,
  }) {
    if (action == 'none') return null;
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;

    IconData icon;
    String label;
    Color color;

    switch (action) {
      case 'mark_read':
        final unread = _appState.unreadCount(contact) > 0;
        icon = unread ? Icons.done_all : Icons.mark_chat_unread_outlined;
        label = unread ? l10n.chatSwipeMarkRead : l10n.chatSwipeMarkUnread;
        color = t.action;
        break;
      case 'mute':
        final muted = contact.isMuted;
        icon = muted
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined;
        label = muted ? l10n.chatSwipeUnmute : l10n.chatSwipeMute;
        color = muted ? t.action : t.textSecondary;
        break;
      case 'pin':
        final pinned = contact.isPinned;
        icon = pinned ? Icons.push_pin_outlined : Icons.push_pin;
        label = pinned ? l10n.chatSwipeUnpin : l10n.chatSwipePin;
        color = t.action;
        break;
      case 'archive':
        icon = Icons.inventory_2_outlined;
        label = l10n.chatSwipeArchive;
        color = t.textSecondary;
        break;
      default:
        return null;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(t.radiusCard),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: t.borderWidth,
        ),
      ),
      alignment: isRightSwipe ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isRightSwipe
            ? [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: t.body.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ]
            : [
                Text(
                  label,
                  style: t.body.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: color, size: 20),
              ],
      ),
    );
  }

  void _executeSwipeAction(String action, Contact c) {
    HapticFeedback.mediumImpact();
    switch (action) {
      case 'mark_read':
        _appState.toggleChatReadUnread(c);
        break;
      case 'mute':
        if (c.isGroup) {
          _showGroupNotificationSettingsSheet(c);
        } else {
          _appState.setChatNotificationMode(c, c.isMuted ? 'all' : 'muted');
        }
        break;
      case 'pin':
        _appState.togglePin(c.keyHash);
        break;
      case 'archive':
        _confirmArchive(c);
        break;
    }
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
    if (c.isPendingEmergency) {
      subtitle = l10n.chatsEmergencyPendingSubtitle;
    } else if (c.isArchived) {
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
          color: c.isPendingEmergency
              ? t.warning.withValues(alpha: 0.05)
              : (wilted ? Colors.transparent : t.surface),
          border: Border.all(
            color: c.isPendingEmergency
                ? t.warning.withValues(alpha: 0.4)
                : (wilted ? t.budgetWilted.withValues(alpha: 0.4) : t.border),
            width: t.borderWidth,
          ),
          borderRadius: BorderRadius.circular(t.radiusCard),
        ),
        child: Row(
          children: [
            PixelArtAvatar(
              hexString: _avatarHex(c),
              size: 44,
              borderId: c.avatarBorderId,
            ),
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
                          c.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (!c.isGroup) ...[
                        const SizedBox(width: 4),
                        ClientIntegrityBadge(badgeType: c.badgeType, size: 13),
                      ],
                      if (c.isPendingEmergency) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: t.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(t.radiusPill),
                            border: Border.all(
                              color: t.warning,
                              width: t.borderWidth,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 8,
                                height: 8,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: t.warning,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                t.uppercaseLabels
                                    ? 'CONNECTING'
                                    : 'Connecting',
                                style: t.badgeLabel.copyWith(
                                  color: t.warning,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (c.isArchived) ...[
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
                      if (c.isMuted) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 13,
                          color: t.textTertiary,
                        ),
                      ] else if (c.isMentionsOnly) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.alternate_email,
                          size: 13,
                          color: t.textTertiary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySecondary.copyWith(
                      color: c.isPendingEmergency ? t.warning : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Time Wilt has no byte budget — the "row below" carries the
                  // lifetime countdown instead of the me/peer byte readout.
                  if (c.isPendingEmergency)
                    Text(
                      'Waiting for contact to connect…',
                      style: t.dataMono.copyWith(color: t.warning),
                    )
                  else if (c.isTimeWilt)
                    Text(
                      c.isArchived
                          ? (t.uppercaseLabels ? 'WILTED' : 'Wilted')
                          : c.isTimeWiltGroupHost
                          ? l10n.groupTimeWiltHostInfinite
                          : 'Wilts in ${c.timeWiltCountdownLabel}',
                      style: t.dataMono.copyWith(
                        color: c.isArchived ? t.textTertiary : t.positive,
                      ),
                    )
                  else
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
            // show their usable budget as our-fraction. Time Wilt reuses the same
            // single gauge for time-remaining (the countdown lives in the row
            // below, so the gauge stays unstacked and never overflows tall
            // vertical gauges like Tideline/Phosphor).
            context.wkc.budgetIndicator(
              ourFraction: c.isTimeWilt
                  ? (c.isTimeWiltGroupHost ? 1.0 : c.timeWiltRemainingFraction)
                  : ourFraction,
              theirFraction: (c.isGroup || c.isTimeWilt)
                  ? 0
                  : c.getTheirChargePercentage(myId),
              isWilted: c.isTimeWilt ? c.isArchived : wilted,
              split: !c.isGroup && !c.isTimeWilt,
              variant: BudgetIndicatorVariant.listRow,
              semanticLabel: c.isTimeWilt
                  ? c.timeWiltCountdownLabel
                  : '$remaining remaining',
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

/// The dashboard's activity-feed button: a bell with a small dot when there are
/// unread events. Replaced the old "+" (create/join/pair) menu — Connect owns those.
class _ActivityBell extends StatelessWidget {
  final int unread;
  final Color color;
  final Color badgeColor;
  final String tooltip;
  final VoidCallback onTap;

  const _ActivityBell({
    required this.unread,
    required this.color,
    required this.badgeColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            unread > 0 ? Icons.notifications : Icons.notifications_none,
            color: color,
            size: 22,
          ),
          if (unread > 0)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.wk.bg, width: 1.5),
                ),
              ),
            ),
        ],
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
                        CopyDebugLogButton(logs: AppState.debugLogs),
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
