part of 'state.dart';

/// State extension for Wilting Stories & WiltKey Social hub.
extension AppStateStories on AppState {
  static List<Story> _storiesFeed = [];
  static SocialBudgetInfo? _socialBudget;
  static bool _isStoriesLoading = false;

  List<Story> get storiesFeed => _storiesFeed;
  SocialBudgetInfo? get socialBudget => _socialBudget;
  bool get isStoriesLoading => _isStoriesLoading;

  /// Loads persisted social account and stories preferences.
  Future<void> loadSocialPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    socialAccountEnabled = prefs.getBool('wk_social_account_enabled') ?? true;
    storiesEnabled = prefs.getBool('wk_stories_enabled') ?? true;
  }

  /// Toggles the user's WiltKey Social account and server-assisted features.
  Future<void> setSocialAccountEnabled(bool enabled) async {
    socialAccountEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wk_social_account_enabled', enabled);
    if (enabled && storiesEnabled) {
      refreshStoriesFeed();
      refreshSocialBudget();
    } else {
      _storiesFeed.clear();
      _socialBudget = null;
    }
    notifyListeners();
  }

  /// Toggles display of the 24-hour Wilting Stories reel on the Chats dashboard.
  Future<void> setStoriesEnabled(bool enabled) async {
    storiesEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wk_stories_enabled', enabled);
    if (enabled && socialAccountEnabled) {
      refreshStoriesFeed();
    }
    notifyListeners();
  }

  /// Refreshes the active stories feed from the relay and decrypts in-memory.
  Future<void> refreshStoriesFeed() async {
    if (userId.isEmpty || !socialAccountEnabled) return;
    _isStoriesLoading = true;
    notifyListeners();

    try {
      final list = await StoryService().fetchFeed(this);
      _storiesFeed = list;
    } catch (e) {
      log('[Stories] Failed to refresh stories feed: $e');
    } finally {
      _isStoriesLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes the weekly social quota and usage gauge from the relay server.
  Future<void> refreshSocialBudget() async {
    if (!isLoaded || userId.isEmpty || !socialAccountEnabled) return;
    try {
      final info = await StoryService().fetchBudget(this);
      _socialBudget = info;
      notifyListeners();
    } catch (e) {
      log('[Stories] Failed to refresh social budget: $e');
    }
  }

  /// Posts a new 24-hour disappearing story (Text, Photo, or Pixel Art).
  Future<void> postNewStory({
    required String storyType,
    required String content,
    String? mediaMeta,
    String? themeId,
    String? caption,
    String? textBorderId,
  }) async {
    await StoryService().postStory(
      appState: this,
      storyType: storyType,
      content: content,
      mediaMeta: mediaMeta,
      themeId: themeId,
      caption: caption,
      textBorderId: textBorderId,
    );
    await refreshStoriesFeed();
    await refreshSocialBudget();

    // Broadcast a lightweight live story_update notification to all active mutual contacts
    _broadcastStoryEvent('story_update', {
      'sender_id': userId,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
  }

  /// Adds or updates a reaction to a story.
  Future<void> reactToStory(String storyId, String emoji) async {
    await StoryService().reactToStory(
      appState: this,
      storyId: storyId,
      emoji: emoji,
    );

    // Find story author
    final idx = _storiesFeed.indexWhere((s) => s.id == storyId);
    if (idx != -1) {
      final targetStory = _storiesFeed[idx];
      final updatedReactions = List<StoryReaction>.from(targetStory.reactions);
      updatedReactions.removeWhere((r) => r.reactorId == userId);
      updatedReactions.add(
        StoryReaction(
          id: '',
          storyId: storyId,
          reactorId: userId,
          emoji: emoji,
          createdAt: DateTime.now(),
        ),
      );
      _storiesFeed[idx] = targetStory.copyWith(reactions: updatedReactions);
      notifyListeners();

      // Broadcast reaction to story author
      if (targetStory.senderId != userId) {
        WebSocketClient().sendWSMessage({
          'type': 'SEND_MESSAGE',
          'recipient_id': targetStory.senderId,
          'content_type': 'story_reaction',
          'envelope': jsonEncode({
            'story_id': storyId,
            'reactor_id': userId,
            'emoji': emoji,
          }),
        });
      }
    }
  }

  void _broadcastStoryEvent(String contentType, Map<String, dynamic> data) {
    final envelope = jsonEncode(data);
    final allContacts = <String>{};
    for (final s in socialContacts) {
      if (!s.isBlocked && s.keyHash != userId) {
        allContacts.add(s.keyHash);
      }
    }

    for (final recipientId in allContacts) {
      WebSocketClient().sendWSMessage({
        'type': 'SEND_MESSAGE',
        'recipient_id': recipientId,
        'content_type': contentType,
        'envelope': envelope,
      });
    }
  }

  /// Fetches reactions list for a user's own story.
  Future<List<StoryReaction>> loadStoryReactions(String storyId) async {
    try {
      return await StoryService().fetchReactions(
        appState: this,
        storyId: storyId,
      );
    } catch (e) {
      log('[Stories] Failed to fetch story reactions: $e');
      return [];
    }
  }

  /// Deletes a story owned by the user.
  Future<void> deleteStory(String storyId) async {
    await StoryService().deleteStory(
      appState: this,
      storyId: storyId,
    );
    _storiesFeed.removeWhere((s) => s.id == storyId);
    notifyListeners();
  }

  /// Wipes all stories, reactions, and social budget records.
  Future<void> wipeAllSocialData() async {
    await StoryService().wipeSocialData(this);
    _storiesFeed.clear();
    _socialBudget = null;
    notifyListeners();
  }
}
