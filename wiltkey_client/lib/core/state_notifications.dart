part of 'state.dart';

const String kPrefNotifyDirectMessages = 'wk_notify_dm';
const String kPrefNotifyGroupMessages = 'wk_notify_groups';
const String kPrefNotifyEvents = 'wk_notify_events';
const String kPrefNotifyMentionsAndReplies = 'wk_notify_mentions_replies';
const String kPrefMutedChats = 'wk_muted_chats';
const String kPrefMentionsOnlyChats = 'wk_mentions_only_chats';

/// Notification configuration and per-chat muting state extension.
extension AppStateNotifications on AppState {
  /// Load persisted notification category toggles from SharedPreferences.
  Future<void> loadNotificationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      notifyDirectMessages = prefs.getBool(kPrefNotifyDirectMessages) ?? true;
      notifyGroupMessages = prefs.getBool(kPrefNotifyGroupMessages) ?? true;
      notifyEvents = prefs.getBool(kPrefNotifyEvents) ?? true;
      notifyMentionsAndReplies =
          prefs.getBool(kPrefNotifyMentionsAndReplies) ?? true;
      await syncMutedChatsToPrefs();
      notifyListeners();
    } catch (e) {
      log('[Notifications] loadNotificationPreferences failed: $e');
    }
  }

  Future<void> setNotifyDirectMessages(bool value) async {
    notifyDirectMessages = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefNotifyDirectMessages, value);
    } catch (_) {}
  }

  Future<void> setNotifyGroupMessages(bool value) async {
    notifyGroupMessages = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefNotifyGroupMessages, value);
    } catch (_) {}
  }

  Future<void> setNotifyEvents(bool value) async {
    notifyEvents = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefNotifyEvents, value);
    } catch (_) {}
  }

  Future<void> setNotifyMentionsAndReplies(bool value) async {
    notifyMentionsAndReplies = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefNotifyMentionsAndReplies, value);
    } catch (_) {}
  }

  /// Sets the per-chat notification mode ('all', 'mentions_only', 'muted').
  Future<void> setChatNotificationMode(Contact contact, String mode) async {
    contact.notificationMode = mode;
    final idx = contacts.indexWhere((c) => c.keyHash == contact.keyHash);
    if (idx != -1) {
      contacts[idx] = contact;
    }
    await WiltkeyDatabase.instance.updateContactNotificationMode(
      contact.keyHash,
      mode,
    );
    await syncMutedChatsToPrefs();
    notifyListeners();
  }

  /// Synchronizes muted and mentions-only keyHashes into SharedPreferences
  /// so background isolates and FCM service can check them without DB access.
  Future<void> syncMutedChatsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mutedHashes = contacts
          .where((c) => c.isMuted)
          .map((c) => c.keyHash)
          .toList();
      final mentionsOnlyHashes = contacts
          .where((c) => c.isMentionsOnly)
          .map((c) => c.keyHash)
          .toList();
      final mutedGroupMemberHashes = <String>{};
      for (final c in contacts) {
        if (c.isGroup && (c.isMuted || c.isMentionsOnly)) {
          mutedGroupMemberHashes.addAll(c.memberKeyHashes);
        }
      }

      await prefs.setStringList(kPrefMutedChats, mutedHashes);
      await prefs.setStringList(kPrefMentionsOnlyChats, mentionsOnlyHashes);
      await prefs.setStringList('wk_muted_group_members', mutedGroupMemberHashes.toList());
    } catch (e) {
      log('[Notifications] syncMutedChatsToPrefs failed: $e');
    }
  }
}
