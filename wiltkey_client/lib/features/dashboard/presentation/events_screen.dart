import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/state.dart';
import '../../../core/models.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../chat/presentation/group_chat_screen.dart';

/// The activity feed — a log of things that happened when the user wasn't
/// looking or that have no chat to live in (a nuke that deleted the chat). Rows
/// are localized by [AppEvent.type] here (the state layer stores an English
/// fallback since it has no BuildContext). Opening this screen marks all read.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onState);
    // Seeing the feed clears the unread badge.
    WidgetsBinding.instance.addPostFrameCallback((_) => _appState.markEventsRead());
  }

  @override
  void dispose() {
    _appState.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  void _openChat(String chatKey) {
    final idx = _appState.contacts.indexWhere((c) => c.keyHash == chatKey);
    if (idx == -1) return; // chat no longer exists (e.g. it was nuked)
    final c = _appState.contacts[idx];
    _appState.selectContact(c);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => c.isGroup ? const GroupChatScreen() : const ChatScreen(),
      ),
    ).then((_) => _appState.clearVisibleChatIfCurrent(c.id));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final events = _appState.events;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        iconTheme: IconThemeData(color: t.action),
        title: Text(
          t.uppercaseLabels
              ? l10n.activityTitle.toUpperCase()
              : l10n.activityTitle,
          style: t.screenTitle.copyWith(fontSize: 18),
        ),
        backgroundColor: t.bg,
        elevation: 0,
        actions: [
          if (events.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(t, l10n),
              child: Text(
                l10n.activityClear,
                style: t.body.copyWith(color: t.action),
              ),
            ),
        ],
      ),
      body: events.isEmpty
          ? _empty(t, l10n)
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                12 + MediaQuery.of(context).viewPadding.bottom,
              ),
              itemCount: events.length,
              itemBuilder: (context, i) => _row(t, l10n, events[i]),
            ),
    );
  }

  Widget _empty(WiltkeyTokens t, AppLocalizations l10n) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none, size: 44, color: t.textTertiary),
              const SizedBox(height: 12),
              Text(
                l10n.activityEmpty,
                textAlign: TextAlign.center,
                style: t.bodySecondary,
              ),
            ],
          ),
        ),
      );

  Widget _row(WiltkeyTokens t, AppLocalizations l10n, AppEvent e) {
    final (icon, title, body) = _present(l10n, e);
    final bool tappable =
        e.chatKey != null &&
        _appState.contacts.any((c) => c.keyHash == e.chatKey);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: e.read ? t.surface : t.action.withValues(alpha: 0.06),
        border: Border.all(
          color: e.read ? t.border : t.action.withValues(alpha: 0.3),
          width: t.borderWidth,
        ),
        borderRadius: BorderRadius.circular(t.radiusCard),
      ),
      child: ListTile(
        onTap: tappable ? () => _openChat(e.chatKey!) : null,
        leading: Icon(icon, color: t.action, size: 22),
        title: Text(
          title,
          style: t.body.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(body, style: t.bodySecondary),
        trailing: Text(
          _relTime(e.timestamp),
          style: t.dataMono.copyWith(fontSize: 11, color: t.textTertiary),
        ),
      ),
    );
  }

  /// Map an event to its icon + localized (title, body). Falls back to the
  /// stored English strings for any type this build doesn't recognize.
  (IconData, String, String) _present(AppLocalizations l10n, AppEvent e) {
    switch (e.type) {
      case 'nuke_received':
        return (
          Icons.local_fire_department_outlined,
          l10n.eventNukeReceivedTitle,
          l10n.eventNukeReceivedBody,
        );
      case 'group_nuked':
        return (
          Icons.local_fire_department_outlined,
          l10n.eventGroupNukedTitle,
          l10n.eventGroupNukedBody,
        );
      default:
        return (Icons.info_outline, e.title, e.body);
    }
  }

  String _relTime(DateTime ts) {
    final d = DateTime.now().difference(ts);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${ts.year}-${ts.month.toString().padLeft(2, '0')}-'
        '${ts.day.toString().padLeft(2, '0')}';
  }

  void _confirmClear(WiltkeyTokens t, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
          side: BorderSide(color: t.border),
        ),
        title: Text(
          l10n.activityClearConfirmTitle,
          style: t.screenTitle.copyWith(fontSize: 16),
        ),
        content: Text(l10n.activityClearConfirmBody, style: t.bodySecondary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text(
              l10n.commonCancel,
              style: TextStyle(color: t.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dctx);
              _appState.clearEvents();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: t.action,
              foregroundColor: t.onAction,
            ),
            child: Text(l10n.activityClear),
          ),
        ],
      ),
    );
  }
}
