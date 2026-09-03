import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:http/http.dart' as http;
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:wiltkey_client/core/chat_metadata.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/persistence.dart';
import 'package:wiltkey_client/core/state.dart';
import 'package:wiltkey_client/core/stories/story_model.dart';
import 'package:wiltkey_client/core/theme/theme_controller.dart';

/// Client service for managing Wilting Stories and querying weekly social quotas.
class StoryService {
  static final StoryService _instance = StoryService._internal();
  factory StoryService() => _instance;
  StoryService._internal();

  /// Posts a new 24h wilting story encrypted for mutual contacts.
  Future<Map<String, dynamic>> postStory({
    required AppState appState,
    required String storyType, // 'text', 'photo', 'pixel_art'
    required String content,
    String? mediaMeta,
    String? themeId,
    String? caption,
    String? textBorderId,
  }) async {
    final myKeyHash = appState.userId;
    final myPubkey = appState.publicKeyHex;
    final myPrivkey = appState.privateKeyHex;
    final relayUrl = appState.activeRelayUrl;

    if (myKeyHash.isEmpty || myPubkey.isEmpty || myPrivkey.isEmpty) {
      throw Exception('Client identity not initialized');
    }

    // 1. Generate ephemeral 256-bit story key
    final storyKeyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final storyKeyHex = hex.encode(storyKeyBytes);

    // 2. Encrypt story payload with story key
    final currentTheme = ThemeController().themeId;
    final payloadJson = jsonEncode({
      'v': 1,
      'type': storyType,
      'content': content,
      'meta': mediaMeta ?? '',
      'theme_id': themeId ?? currentTheme,
      'caption': caption ?? '',
      'text_border_id': textBorderId ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    final encBody = WiltkeyPersistence().encryptString(payloadJson, storyKeyHex);

    // 3. Wrap storyKey for each known contact (and self)
    final Map<String, String> wrappedKeys = {};

    // Wrap for self using secret master key (never shared with relay or network)
    final localMasterKey = appState.masterKeyHex;
    if (localMasterKey != null && localMasterKey.isNotEmpty) {
      final selfWrapped = WiltkeyPersistence().encryptString(storyKeyHex, localMasterKey);
      wrappedKeys[myKeyHash] = selfWrapped;
    }

    // Wrap for all active non-blocked social contacts (friends only)
    final allContacts = <String>{};
    for (final s in appState.socialContacts) {
      if (!s.isBlocked && s.keyHash != myKeyHash) {
        allContacts.add(s.keyHash);
      }
    }

    for (final contactHash in allContacts) {
      final metaKey = await ChatMetaStore.keyFor(contactHash);
      if (metaKey != null && metaKey.isNotEmpty) {
        final wrapped = WiltkeyPersistence().encryptString(storyKeyHex, metaKey);
        wrappedKeys[contactHash] = wrapped;
      }
    }

    final envelopeJson = jsonEncode({
      'body': encBody,
      'keys': wrappedKeys,
    });

    // 4. Ed25519 signature
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signMessage = 'WILTKEY_STORY_POST:$myKeyHash:$storyType:$timestamp';
    final privBytes = hex.decode(myPrivkey);
    final privKey = ed.PrivateKey(privBytes);
    final sigBytes = ed.sign(privKey, utf8.encode(signMessage));
    final sigHex = hex.encode(sigBytes);

    final url = Uri.parse('$relayUrl/api/v1/stories/post');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': myKeyHash,
        'pubkey': myPubkey,
        'timestamp': timestamp,
        'sig': sigHex,
        'story_type': storyType,
        'ciphertext_b64': envelopeJson,
        'media_meta': mediaMeta ?? '',
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to post story (${response.statusCode})');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Fetches stories feed from relay for self and all mutual contacts.
  Future<List<Story>> fetchFeed(AppState appState) async {
    final myKeyHash = appState.userId;
    final myPubkey = appState.publicKeyHex;
    final myPrivkey = appState.privateKeyHex;
    final relayUrl = appState.activeRelayUrl;

    if (myKeyHash.isEmpty || myPubkey.isEmpty || myPrivkey.isEmpty) {
      return [];
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signMessage = 'WILTKEY_STORY_FEED:$myKeyHash:$timestamp';
    final privBytes = hex.decode(myPrivkey);
    final privKey = ed.PrivateKey(privBytes);
    final sigBytes = ed.sign(privKey, utf8.encode(signMessage));
    final sigHex = hex.encode(sigBytes);

    final contactHashes = <String>{};
    for (final s in appState.socialContacts) {
      if (!s.isBlocked) contactHashes.add(s.keyHash);
    }

    final url = Uri.parse('$relayUrl/api/v1/stories/feed');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': myKeyHash,
        'pubkey': myPubkey,
        'timestamp': timestamp,
        'sig': sigHex,
        'contacts': contactHashes.toList(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch stories feed (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawStories = (data['stories'] as List?) ?? [];
    final List<Story> decryptedStories = [];

    for (final item in rawStories) {
      try {
        final storyMap = item as Map<String, dynamic>;
        final storyId = storyMap['id'] as String;
        final senderId = storyMap['sender_id'] as String;
        final storyType = storyMap['story_type'] as String;
        final cipherEnvelopeStr = storyMap['ciphertext_b64'] as String;
        final createdAtStr = storyMap['created_at'] as String;
        final expiresAtStr = storyMap['expires_at'] as String;
        final bytesUsed = (storyMap['bytes_used'] as num?)?.toInt() ?? 0;

        final envelope = jsonDecode(cipherEnvelopeStr) as Map<String, dynamic>;
        final encBody = envelope['body'] as String;
        final keys = (envelope['keys'] as Map<String, dynamic>?) ?? {};

        String? storyKeyHex;
        if (senderId == myKeyHash) {
          final selfWrapped = keys[myKeyHash] as String?;
          final localMasterKey = appState.masterKeyHex;
          if (selfWrapped != null && localMasterKey != null) {
            storyKeyHex = WiltkeyPersistence().decryptString(selfWrapped, localMasterKey);
          }
        } else {
          final wrappedKey = keys[myKeyHash] as String?;
          if (wrappedKey != null) {
            final metaKey = await ChatMetaStore.keyFor(senderId);
            if (metaKey != null) {
              storyKeyHex = WiltkeyPersistence().decryptString(wrappedKey, metaKey);
            }
          }
        }

        if (storyKeyHex == null || storyKeyHex.isEmpty) {
          continue; // cannot decrypt
        }

        final plainBodyJson = WiltkeyPersistence().decryptString(encBody, storyKeyHex);
        if (plainBodyJson == null || plainBodyJson.isEmpty) continue;

        final bodyData = jsonDecode(plainBodyJson) as Map<String, dynamic>;
        final plainContent = bodyData['content'] as String? ?? '';
        final mediaMeta = bodyData['meta'] as String? ?? '';
        final themeId = bodyData['theme_id'] as String?;
        final caption = bodyData['caption'] as String?;
        final textBorderId = bodyData['text_border_id'] as String?;

        decryptedStories.add(
          Story(
            id: storyId,
            senderId: senderId,
            storyType: storyType,
            content: plainContent,
            mediaMeta: mediaMeta,
            themeId: themeId,
            caption: caption,
            textBorderId: textBorderId,
            createdAt: DateTime.tryParse(createdAtStr) ?? DateTime.now(),
            expiresAt: DateTime.tryParse(expiresAtStr) ?? DateTime.now(),
            bytesUsed: bytesUsed,
            isMine: senderId == myKeyHash,
          ),
        );
      } catch (e) {
        // Skip undecryptable or malformed story
      }
    }

    return decryptedStories;
  }

  /// Sends a reaction emoji to a story.
  Future<void> reactToStory({
    required AppState appState,
    required String storyId,
    required String emoji,
  }) async {
    final myKeyHash = appState.userId;
    final myPubkey = appState.publicKeyHex;
    final myPrivkey = appState.privateKeyHex;
    final relayUrl = appState.activeRelayUrl;

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signMessage = 'WILTKEY_STORY_REACT:$myKeyHash:$storyId:$emoji:$timestamp';
    final privBytes = hex.decode(myPrivkey);
    final privKey = ed.PrivateKey(privBytes);
    final sigBytes = ed.sign(privKey, utf8.encode(signMessage));
    final sigHex = hex.encode(sigBytes);

    final url = Uri.parse('$relayUrl/api/v1/stories/react');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': myKeyHash,
        'pubkey': myPubkey,
        'timestamp': timestamp,
        'sig': sigHex,
        'story_id': storyId,
        'emoji': emoji,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to record reaction (${response.statusCode})');
    }
  }

  /// Fetches reactions for the user's own story.
  Future<List<StoryReaction>> fetchReactions({
    required AppState appState,
    required String storyId,
  }) async {
    final myKeyHash = appState.userId;
    final myPubkey = appState.publicKeyHex;
    final myPrivkey = appState.privateKeyHex;
    final relayUrl = appState.activeRelayUrl;

    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final signMessage = 'WILTKEY_STORY_REACTIONS:$storyId:$myKeyHash:$timestamp';
    final privBytes = hex.decode(myPrivkey);
    final privKey = ed.PrivateKey(privBytes);
    final sigBytes = ed.sign(privKey, utf8.encode(signMessage));
    final sigHex = hex.encode(sigBytes);

    final uri = Uri.parse('$relayUrl/api/v1/stories/$storyId/reactions').replace(
      queryParameters: {
        'user_id': myKeyHash,
        'pubkey': myPubkey,
        'timestamp': timestamp,
        'sig': sigHex,
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (data['reactions'] as List?) ?? [];
    return list.map((r) => StoryReaction.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Deletes a story owned by the user.
  Future<void> deleteStory({
    required AppState appState,
    required String storyId,
  }) async {
    final myKeyHash = appState.userId;
    final myPubkey = appState.publicKeyHex;
    final myPrivkey = appState.privateKeyHex;
    final relayUrl = appState.activeRelayUrl;

    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final signMessage = 'WILTKEY_STORY_DELETE:$storyId:$myKeyHash:$timestamp';
    final privBytes = hex.decode(myPrivkey);
    final privKey = ed.PrivateKey(privBytes);
    final sigBytes = ed.sign(privKey, utf8.encode(signMessage));
    final sigHex = hex.encode(sigBytes);

    final uri = Uri.parse('$relayUrl/api/v1/stories/$storyId').replace(
      queryParameters: {
        'user_id': myKeyHash,
        'pubkey': myPubkey,
        'timestamp': timestamp,
        'sig': sigHex,
      },
    );

    final response = await http.delete(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete story (${response.statusCode})');
    }
  }

  /// Queries weekly social budget status from relay.
  Future<SocialBudgetInfo> fetchBudget(AppState appState) async {
    final myKeyHash = appState.userId;
    final myPubkey = appState.publicKeyHex;
    final myPrivkey = appState.privateKeyHex;
    final relayUrl = appState.activeRelayUrl;

    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final signMessage = 'WILTKEY_SOCIAL_BUDGET:$myKeyHash:$timestamp';
    final privBytes = hex.decode(myPrivkey);
    final privKey = ed.PrivateKey(privBytes);
    final sigBytes = ed.sign(privKey, utf8.encode(signMessage));
    final sigHex = hex.encode(sigBytes);

    final uri = Uri.parse('$relayUrl/api/v1/social/budget').replace(
      queryParameters: {
        'user_id': myKeyHash,
        'pubkey': myPubkey,
        'timestamp': timestamp,
        'sig': sigHex,
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch social budget (${response.statusCode})');
    }

    return SocialBudgetInfo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Performs a signed one-tap wipe of all active stories and social data.
  Future<void> wipeSocialData(AppState appState) async {
    final myKeyHash = appState.userId;
    final myPubkey = appState.publicKeyHex;
    final myPrivkey = appState.privateKeyHex;
    final relayUrl = appState.activeRelayUrl;

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signMessage = 'WILTKEY_SOCIAL_WIPE:$myKeyHash:$timestamp';
    final privBytes = hex.decode(myPrivkey);
    final privKey = ed.PrivateKey(privBytes);
    final sigBytes = ed.sign(privKey, utf8.encode(signMessage));
    final sigHex = hex.encode(sigBytes);

    final url = Uri.parse('$relayUrl/api/v1/social/wipe');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': myKeyHash,
        'pubkey': myPubkey,
        'timestamp': timestamp,
        'sig': sigHex,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to wipe social data (${response.statusCode})');
    }
  }
}
