import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/pixel_art_avatar.dart';
import 'package:wiltkey_client/core/state.dart';
import 'package:wiltkey_client/core/stories/story_model.dart';
import 'package:wiltkey_client/core/theme/theme_registry.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import 'widgets/themed_story_text_tag.dart';

/// Full-screen interactive story player with 24h countdown bar, floating reactions,
/// author theme reproduction, and themed borders.
class StoryViewerScreen extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  static Future<void> open(
    BuildContext context, {
    required List<Story> stories,
    int initialIndex = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StoryViewerScreen(
          stories: stories,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  final AppState _appState = AppState();
  late final PageController _pageController;
  late int _currentIndex;

  late final AnimationController _progressAnim;
  static const Duration _storyDuration = Duration(seconds: 8);

  bool _isPaused = false;
  List<StoryReaction> _authorReactions = [];
  final Map<String, Uint8List> _decodedImageCache = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Pre-cache all decoded story images in memory to prevent black flicker during swipes
    for (final s in widget.stories) {
      if (s.storyType == 'photo') {
        try {
          _decodedImageCache[s.id] = base64Decode(s.content);
        } catch (_) {}
      }
    }

    _progressAnim = AnimationController(
      vsync: this,
      duration: _storyDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });

    _startCurrentStory();
  }

  @override
  void dispose() {
    _progressAnim.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _startCurrentStory() {
    _progressAnim.reset();
    _progressAnim.forward();
    _loadReactionsIfMine();
  }

  Future<void> _loadReactionsIfMine() async {
    if (_currentIndex < 0 || _currentIndex >= widget.stories.length) return;
    final story = widget.stories[_currentIndex];
    if (story.isMine) {
      final list = await _appState.loadStoryReactions(story.id);
      if (mounted) {
        setState(() => _authorReactions = list);
      }
    }
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      _pageController.animateToPage(
        _currentIndex + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      _pageController.animateToPage(
        _currentIndex - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
      _startCurrentStory();
    }
  }

  void _pause() {
    setState(() => _isPaused = true);
    _progressAnim.stop();
  }

  void _resume() {
    setState(() => _isPaused = false);
    _progressAnim.forward();
  }

  WiltkeyTokens _resolveStoryTheme(Story story, WiltkeyTokens fallback) {
    if (story.themeId != null && story.themeId!.isNotEmpty) {
      try {
        final themeData = WiltkeyThemeRegistry.byId(story.themeId!).build();
        return themeData.extension<WiltkeyTokens>() ?? fallback;
      } catch (_) {}
    }
    return fallback;
  }

  String _authorDisplayName(Story story) {
    if (story.isMine) return 'You';
    final sc = _appState.socialContacts.firstWhere(
      (c) => c.keyHash == story.senderId,
      orElse: () => SocialContact(
        id: 0,
        keyHash: story.senderId,
        name: 'Contact (${story.senderId.length >= 6 ? story.senderId.substring(0, 6) : story.senderId})',
        shortNick: 'WK',
        sharedSecretSeed: '',
        myPubkey: '',
        peerPubkey: '',
        addedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ),
    );
    return sc.displayName;
  }

  String? _authorAvatar(Story story) {
    if (story.isMine) return _appState.profileImageB64;
    final sc = _appState.socialContacts.firstWhere(
      (c) => c.keyHash == story.senderId,
      orElse: () => SocialContact(
        id: 0,
        keyHash: story.senderId,
        name: '',
        shortNick: '',
        sharedSecretSeed: '',
        myPubkey: '',
        peerPubkey: '',
        addedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ),
    );
    return sc.profileImageB64;
  }

  String? _authorBorder(Story story) {
    if (story.isMine) return null;
    final sc = _appState.socialContacts.firstWhere(
      (c) => c.keyHash == story.senderId,
      orElse: () => SocialContact(
        id: 0,
        keyHash: story.senderId,
        name: '',
        shortNick: '',
        sharedSecretSeed: '',
        myPubkey: '',
        peerPubkey: '',
        addedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ),
    );
    return sc.avatarBorderId;
  }

  Future<void> _sendReaction(String emoji) async {
    HapticFeedback.lightImpact();
    final story = widget.stories[_currentIndex];
    await _appState.reactToStory(story.id, emoji);
    setState(() {});
  }

  Map<String, int> _calculateReactionCounts(List<StoryReaction> reactions) {
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    return counts;
  }

  void _showAuthorReactionsSheet(BuildContext context, WiltkeyTokens t) {
    _pause();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
        side: BorderSide(color: t.border),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite, size: 18, color: t.danger),
                  const SizedBox(width: 8),
                  Text(
                    'Reactions (${_authorReactions.length})',
                    style: t.screenTitle.copyWith(fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: t.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_authorReactions.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No reactions yet', style: t.bodySecondary),
                  ),
                ),
              ] else ...[
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _authorReactions.length,
                    separatorBuilder: (_, __) => Divider(color: t.border, height: 1),
                    itemBuilder: (ctx, i) {
                      final r = _authorReactions[i];
                      final sc = _appState.socialContacts.firstWhere(
                        (c) => c.keyHash == r.reactorId,
                        orElse: () => SocialContact(
                          id: 0,
                          keyHash: r.reactorId,
                          name: 'Contact',
                          shortNick: 'WK',
                          sharedSecretSeed: '',
                          myPubkey: '',
                          peerPubkey: '',
                          addedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                        ),
                      );
                      return ListTile(
                        leading: PixelArtAvatar(
                          hexString: sc.profileImageB64 ?? '',
                          size: 32,
                          borderId: sc.avatarBorderId,
                        ),
                        title: Text(sc.displayName, style: t.body),
                        trailing: Text(r.emoji, style: const TextStyle(fontSize: 22)),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ).whenComplete(_resume);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final story = widget.stories[_currentIndex];
    final storyTheme = _resolveStoryTheme(story, t);
    final activeReactions = story.isMine ? _authorReactions : story.reactions;
    final reactionCounts = _calculateReactionCounts(activeReactions);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onLongPressStart: (_) => _pause(),
          onLongPressEnd: (_) => _resume(),
          child: Stack(
            children: [
              // Page View
              PageView.builder(
                controller: _pageController,
                physics: const PageScrollPhysics(),
                onPageChanged: _onPageChanged,
                itemCount: widget.stories.length,
                itemBuilder: (context, index) {
                  final s = widget.stories[index];
                  final st = _resolveStoryTheme(s, t);
                  return _buildStoryContent(s, st);
                },
              ),

              // Tap Zones (Left = Prev, Right = Next)
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _prevStory,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _nextStory,
                      ),
                    ),
                  ],
                ),
              ),

              // Top Bars & Header
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: Column(
                  children: [
                    // Segmented Progress Bar
                    Row(
                      children: List.generate(widget.stories.length, (i) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: AnimatedBuilder(
                              animation: _progressAnim,
                              builder: (context, _) {
                                double val = 0.0;
                                if (i < _currentIndex) {
                                  val = 1.0;
                                } else if (i == _currentIndex) {
                                  val = _progressAnim.value;
                                }
                                return LinearProgressIndicator(
                                  value: val,
                                  minHeight: 2.5,
                                  backgroundColor: Colors.white24,
                                  valueColor: AlwaysStoppedAnimation<Color>(storyTheme.action),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),

                    // Author Header Row
                    Row(
                      children: [
                        PixelArtAvatar(
                          hexString: _authorAvatar(story) ?? '',
                          size: 38,
                          borderId: _authorBorder(story),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _authorDisplayName(story),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Expires in ${story.remainingTimeLabel}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),

                        // If own story: options
                        if (story.isMine) ...[
                          IconButton(
                            icon: const Icon(Icons.favorite_border, color: Colors.white, size: 20),
                            onPressed: () => _showAuthorReactionsSheet(context, t),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                            onPressed: () async {
                              _pause();
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: t.surface,
                                  title: Text('Delete Story', style: t.screenTitle.copyWith(fontSize: 16)),
                                  content: Text('Permanently delete this wilting story?', style: t.body),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: Text('CANCEL', style: t.bodySecondary),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: t.danger),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('DELETE'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _appState.deleteStory(story.id);
                                if (context.mounted) Navigator.pop(context);
                              } else {
                                _resume();
                              }
                            },
                          ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Floating Reactions Capsule Row
              if (reactionCounts.isNotEmpty)
                Positioned(
                  bottom: story.isMine ? 24 : 76,
                  left: 16,
                  right: 16,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: reactionCounts.entries.map((entry) {
                      final emoji = entry.key;
                      final count = entry.value;
                      final hasMyReaction = activeReactions.any(
                        (r) => r.reactorId == _appState.userId && r.emoji == emoji,
                      );

                      return GestureDetector(
                        onTap: () {
                          if (story.isMine) {
                            _showAuthorReactionsSheet(context, t);
                          } else {
                            _sendReaction(emoji);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: hasMyReaction ? storyTheme.action : Colors.white24,
                              width: hasMyReaction ? 1.5 : 1.0,
                            ),
                            boxShadow: hasMyReaction
                                ? [
                                    BoxShadow(
                                      color: storyTheme.action.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 4),
                              Text(
                                '$count',
                                style: TextStyle(
                                  color: hasMyReaction ? storyTheme.action : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // Bottom Reactions Picker Bar (for peer stories)
              if (!story.isMine)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final emoji in ['❤️', '🔥', '😂', '😮', '👏', '🙏'])
                          GestureDetector(
                            onTap: () => _sendReaction(emoji),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Text(emoji, style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoryContent(Story s, WiltkeyTokens st) {
    switch (s.storyType) {
      case 'photo':
        final bytes = _decodedImageCache[s.id] ?? (s.content.isNotEmpty ? base64Decode(s.content) : null);
        if (bytes == null) {
          return const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48));
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
            ),
            if (s.caption != null && s.caption!.isNotEmpty)
              Positioned(
                bottom: 120,
                left: 24,
                right: 24,
                child: Center(
                  child: CustomPaint(
                    painter: ThemedTagBackgroundPainter(
                      styleId: s.textBorderId ?? StoryTextStyles.cyberpunk,
                      primaryAccent: st.action,
                      tokens: st,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Text(
                        s.caption!,
                        textAlign: TextAlign.center,
                        style: st.body.copyWith(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          shadows: s.textBorderId == StoryTextStyles.none
                              ? const [Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1))]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );

      case 'pixel_art':
        return Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(st.radiusCard),
                  border: Border.all(color: Colors.white24),
                ),
                child: PixelArtAvatar(hexString: s.content, size: 260),
              ),
            ),
            if (s.caption != null && s.caption!.isNotEmpty)
              Positioned(
                bottom: 120,
                left: 24,
                right: 24,
                child: Center(
                  child: CustomPaint(
                    painter: ThemedTagBackgroundPainter(
                      styleId: s.textBorderId ?? StoryTextStyles.cyberpunk,
                      primaryAccent: st.action,
                      tokens: st,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Text(
                        s.caption!,
                        textAlign: TextAlign.center,
                        style: st.body.copyWith(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          shadows: s.textBorderId == StoryTextStyles.none
                              ? const [Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1))]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );

      case 'text':
      default:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: CustomPaint(
              painter: ThemedTagBackgroundPainter(
                styleId: s.textBorderId ?? StoryTextStyles.cyberpunk,
                primaryAccent: st.action,
                tokens: st,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Text(
                  s.content,
                  textAlign: TextAlign.center,
                  style: st.screenTitle.copyWith(
                    fontSize: 22,
                    height: 1.4,
                    color: st.textPrimary,
                    shadows: s.textBorderId == StoryTextStyles.none
                        ? const [Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2))]
                        : null,
                  ),
                ),
              ),
            ),
          ),
        );
    }
  }
}
