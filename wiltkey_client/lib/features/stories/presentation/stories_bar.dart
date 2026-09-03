import 'package:flutter/material.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/pixel_art_avatar.dart';
import 'package:wiltkey_client/core/state.dart';
import 'package:wiltkey_client/core/stories/story_model.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import 'create_story_sheet.dart';
import 'story_viewer_screen.dart';

/// Horizontal stories reel widget that can be placed at the top of Chats tab or Social Hub.
class StoriesBar extends StatelessWidget {
  const StoriesBar({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final appState = AppState();

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final stories = appState.storiesFeed;
        final myStory = stories.where((s) => s.isMine).toList();

        // Group peer stories by sender (strictly for mutual social contacts)
        final Map<String, List<Story>> senderStories = {};
        for (final s in stories) {
          if (!s.isMine) {
            final isSocialContact = appState.socialContacts.any(
              (sc) => sc.keyHash == s.senderId && !sc.isBlocked,
            );
            if (isSocialContact) {
              senderStories.putIfAbsent(s.senderId, () => []).add(s);
            }
          }
        }

        return Container(
          height: 96,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Add / View My Story
              _buildMyStoryItem(context, t, appState, myStory),
              const SizedBox(width: 12),

              // Peer Stories
              for (final entry in senderStories.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: _buildPeerStoryItem(context, t, appState, entry.key, entry.value, stories),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyStoryItem(
    BuildContext context,
    WiltkeyTokens t,
    AppState appState,
    List<Story> myStories,
  ) {
    final hasStory = myStories.isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (hasStory) {
          StoryViewerScreen.open(context, stories: myStories);
        } else {
          CreateStorySheet.show(context);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasStory ? t.action : t.border,
                    width: hasStory ? 2.0 : 1.0,
                  ),
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: PixelArtAvatar(
                      hexString: appState.profileImageB64,
                      size: 46,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: GestureDetector(
                  onTap: () => CreateStorySheet.show(context),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: t.action,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.surface, width: 1.5),
                    ),
                    child: Icon(
                      hasStory ? Icons.add : Icons.add,
                      size: 14,
                      color: t.onAction,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hasStory ? 'Your Story' : 'Add Story',
            style: t.badgeLabel.copyWith(
              fontSize: 10,
              color: hasStory ? t.action : t.textSecondary,
              fontWeight: hasStory ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeerStoryItem(
    BuildContext context,
    WiltkeyTokens t,
    AppState appState,
    String senderId,
    List<Story> senderStoriesList,
    List<Story> allFeedStories,
  ) {
    final sc = appState.socialContacts.firstWhere(
      (c) => c.keyHash == senderId,
      orElse: () => SocialContact(
        id: 0,
        keyHash: senderId,
        name: 'Contact',
        shortNick: 'WK',
        sharedSecretSeed: '',
        myPubkey: '',
        peerPubkey: '',
        addedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ),
    );

    return GestureDetector(
      onTap: () {
        final initialIndex = allFeedStories.indexOf(senderStoriesList.first);
        StoryViewerScreen.open(
          context,
          stories: allFeedStories,
          initialIndex: initialIndex != -1 ? initialIndex : 0,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.positive, width: 2.0),
              boxShadow: [
                BoxShadow(
                  color: t.positive.withValues(alpha: 0.3),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: SizedBox(
                width: 46,
                height: 46,
                child: PixelArtAvatar(
                  hexString: sc.profileImageB64 ?? '',
                  size: 46,
                  borderId: sc.avatarBorderId,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 60,
            child: Text(
              sc.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: t.badgeLabel.copyWith(fontSize: 10, color: t.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
