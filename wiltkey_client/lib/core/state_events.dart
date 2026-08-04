part of 'state.dart';

/// The global activity feed. Records things that happened when the user wasn't
/// looking, or that have no chat to live in (a nuke that deleted the chat).
///
/// Rule of thumb for what belongs here (see [[activity-feed-plan]]): log an
/// event only when there is **no chat to hold it** (nuke-received) or the user
/// **couldn't have seen the chat's own system note** (it arrived backgrounded).
/// Events that already leave an in-chat system message (member joined, host
/// recharged while you're in the chat) should NOT be double-logged reflexively.
///
/// Entries are plaintext-at-rest and wiped by nuke ([WiltkeyDatabase.deleteAll]
/// also clears the `events` table). Any OS notification stays content-free.
extension AppStateEvents on AppState {
  int get unreadEventCount => events.where((e) => !e.read).length;

  /// Load the newest events into memory (called on startup). Also prunes the
  /// on-disk log so it can't grow without bound.
  Future<void> loadEvents() async {
    try {
      await WiltkeyDatabase.instance.pruneEvents(keep: 200);
      final rows = await WiltkeyDatabase.instance.getEvents(limit: 200);
      events = rows.map((r) => AppEvent.fromRow(r)).toList();
      notifyListeners();
    } catch (e) {
      log('[Events] load failed: $e');
    }
  }

  /// Append an activity event (persist + surface). [chatKey] deep-links to a
  /// chat when it still exists. Idempotent per [id] so a redelivered signal
  /// doesn't spawn a duplicate row.
  Future<void> logEvent({
    required String type,
    required String title,
    required String body,
    String? chatKey,
    String? id,
  }) async {
    final ev = AppEvent(
      id: id ?? '${type}_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      title: title,
      body: body,
      chatKey: chatKey,
      timestamp: DateTime.now(),
    );
    // De-dupe in memory (idempotent redelivery).
    if (events.any((e) => e.id == ev.id)) return;
    events.insert(0, ev);
    try {
      await WiltkeyDatabase.instance.insertEvent(ev.toRow());
    } catch (e) {
      log('[Events] persist failed: $e');
    }
    notifyListeners();
  }

  /// Mark the whole feed read (called when the user opens the events screen).
  Future<void> markEventsRead() async {
    if (unreadEventCount == 0) return;
    for (final e in events) {
      e.read = true;
    }
    try {
      await WiltkeyDatabase.instance.markAllEventsRead();
    } catch (e) {
      log('[Events] markRead failed: $e');
    }
    notifyListeners();
  }

  /// Clear the entire feed (user action).
  Future<void> clearEvents() async {
    events = [];
    try {
      await WiltkeyDatabase.instance.clearEvents();
    } catch (e) {
      log('[Events] clear failed: $e');
    }
    notifyListeners();
  }

  /// Drop a contact's events when that chat is destroyed locally, so a wiped
  /// chat leaves no lingering feed rows pointing at a dead keyHash.
  Future<void> purgeEventsForChat(String chatKey) async {
    events.removeWhere((e) => e.chatKey == chatKey);
    try {
      await WiltkeyDatabase.instance.deleteEventsForChat(chatKey);
    } catch (e) {
      log('[Events] purge failed: $e');
    }
    notifyListeners();
  }
}
