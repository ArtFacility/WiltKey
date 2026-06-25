// Custom emoji harness.
//
// Covers the shared per-chat emoji pool end to end:
//   * activeEmojiQuery — the pure autocomplete parser
//   * CustomEmojiStore.mergeAll — union by name, newer-wins, budget trim
//   * tombstone semantics — a deletion (deleted:true, newer ts) wins the merge
//     and its reservedBytes keeps costing budget (space is burned, not freed)
//   * 1-on-1 chat_emoji_sync — AES round-trip over the derived metadata key
//   * group group_emoji_sync — host merges a member's pool and re-broadcasts it
//
// The sync tests drive the REAL dispatch path (AppState + the in-process relay
// handshake), mirroring chat_info_test.dart / group_protocol_test.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiltkey_client/core/state.dart';
import 'package:wiltkey_client/core/custom_emoji.dart';
import 'package:wiltkey_client/core/crypto/otp_service.dart';
import 'package:wiltkey_client/core/network/websocket_client.dart';
import 'package:wiltkey_client/features/chat/presentation/widgets/emoji_autocomplete_bar.dart';

class MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getTemporaryPath() async => '.';
  @override
  Future<String?> getApplicationSupportPath() async => '.';
  @override
  Future<String?> getLibraryPath() async => '.';
  @override
  Future<String?> getApplicationDocumentsPath() async => '.';
  @override
  Future<String?> getExternalStoragePath() async => '.';
  @override
  Future<List<String>?> getExternalCachePaths() async => [];
  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => [];
  @override
  Future<String?> getDownloadsPath() async => '.';
}

CustomEmoji _emoji(String name, {int ts = 1000, String img = 'aGVsbG8='}) =>
    CustomEmoji(name: name, imageB64: img, createdAtMs: ts);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  PathProviderPlatform.instance = MockPathProviderPlatform();
  const MethodChannel(
    'plugins.flutter.io/shared_preferences',
  ).setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'getAll') return <String, dynamic>{};
    return true;
  });

  // ---------------------------------------------------------------------------
  // 1) activeEmojiQuery — pure parser
  // ---------------------------------------------------------------------------
  group('activeEmojiQuery', () {
    test('returns the partial token inside an open colon', () {
      expect(activeEmojiQuery('hello :wav', 10), equals('wav'));
      expect(activeEmojiQuery(':pa', 3), equals('pa'));
    });

    test('lowercases the query', () {
      expect(activeEmojiQuery(':PA', 3), equals('pa'));
    });

    test('null when the token is closed or empty', () {
      expect(activeEmojiQuery(':smile:', 7), isNull); // already closed
      expect(activeEmojiQuery(':', 1), isNull); // nothing typed yet
      expect(activeEmojiQuery('plain text', 10), isNull); // no colon
    });

    test('stops at whitespace / non-name chars before the colon', () {
      expect(activeEmojiQuery(':foo bar', 8), isNull);
    });

    test('uses the colon nearest the caret', () {
      // caret right after "wav" — the open token is :wav, not the closed :a:
      expect(activeEmojiQuery(':a: :wav', 8), equals('wav'));
    });
  });

  // ---------------------------------------------------------------------------
  // 2) mergeAll + tombstones (CustomEmojiStore, no relay needed)
  // ---------------------------------------------------------------------------
  group('CustomEmojiStore.mergeAll', () {
    test('union-merges and newer createdAtMs wins', () async {
      final key = 'merge_${DateTime.now().microsecondsSinceEpoch}';
      await CustomEmojiStore.clear(key);
      await CustomEmojiStore.add(key, _emoji('aa', ts: 100));

      final changed = await CustomEmojiStore.mergeAll(key, [
        _emoji('aa', ts: 50, img: 'b2xk'), // older — must NOT overwrite
        _emoji('bb', ts: 200), // new entry
      ]);
      expect(changed, isTrue);

      final map = CustomEmojiStore.cachedMap(key);
      expect(map.keys, containsAll(<String>['aa', 'bb']));
      expect(
        map['aa']!.createdAtMs,
        equals(100),
        reason: 'older incoming must lose',
      );

      // A second identical merge changes nothing.
      final again = await CustomEmojiStore.mergeAll(key, [
        _emoji('aa', ts: 50),
      ]);
      expect(again, isFalse);
    });

    test('trims oldest beyond maxBytes', () async {
      final key = 'trim_${DateTime.now().microsecondsSinceEpoch}';
      await CustomEmojiStore.clear(key);
      // Each img is 8 base64 chars => 8 bytes apiece.
      await CustomEmojiStore.mergeAll(key, [
        _emoji('old', ts: 1, img: 'AAAAAAAA'),
        _emoji('new', ts: 2, img: 'BBBBBBBB'),
      ], maxBytes: 8); // only room for one

      final names = CustomEmojiStore.cached(key).map((e) => e.name).toList();
      expect(
        names,
        equals(['new']),
        reason: 'oldest is trimmed to fit the budget',
      );
    });

    test('a tombstone wins the merge and its bytes stay counted', () async {
      final key = 'tomb_${DateTime.now().microsecondsSinceEpoch}';
      await CustomEmojiStore.clear(key);
      await CustomEmojiStore.add(
        key,
        _emoji('xx', ts: 100, img: 'AAAAAAAA'),
      ); // 8 bytes
      final liveBytes = CustomEmojiStore.totalBytes(key);
      expect(liveBytes, equals(8));

      // Incoming tombstone for 'xx' with a newer timestamp.
      final tomb = CustomEmoji(
        name: 'xx',
        imageB64: '',
        createdAtMs: 500,
        deleted: true,
        reservedBytes: 8,
      );
      final changed = await CustomEmojiStore.mergeAll(key, [tomb]);
      expect(changed, isTrue);

      // No longer rendered/usable...
      expect(CustomEmojiStore.cachedMap(key).containsKey('xx'), isFalse);
      // ...but the burned slot still costs the budget.
      expect(CustomEmojiStore.totalBytes(key), equals(8));
      expect(CustomEmojiStore.cached(key).single.deleted, isTrue);
    });

    test('local tombstone() bumps timestamp and drops the image', () async {
      final key = 'localtomb_${DateTime.now().microsecondsSinceEpoch}';
      await CustomEmojiStore.clear(key);
      await CustomEmojiStore.add(key, _emoji('yy', ts: 100, img: 'AAAAAAAA'));
      await CustomEmojiStore.tombstone(key, 'yy');

      final t = CustomEmojiStore.cached(key).single;
      expect(t.deleted, isTrue);
      expect(t.imageB64, isEmpty);
      expect(t.reservedBytes, equals(8));
      expect(t.createdAtMs, greaterThan(100));
    });
  });

  // ---------------------------------------------------------------------------
  // 3) + 4) sync round-trips (full AppState + relay handshake)
  // ---------------------------------------------------------------------------
  group('emoji sync', () {
    late AppState appState;
    late HttpServer server;
    const String seed =
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
    const String groupSeed =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const int laneSize = 64 * 1024;
    const int maxMembers = 4;
    final int totalSize = AppState.infoLaneSize + maxMembers * laneSize;
    final String memberA = 'a' * 64;

    Future<void> startFakeRelay() async {
      server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((HttpRequest req) async {
        if (req.uri.path == '/ws' &&
            WebSocketTransformer.isUpgradeRequest(req)) {
          final socket = await WebSocketTransformer.upgrade(req);
          socket.add(
            jsonEncode({'type': 'CHALLENGE', 'challenge': 'deadbeef'}),
          );
          socket.listen((data) {
            try {
              final msg = jsonDecode(data as String) as Map<String, dynamic>;
              if (msg['type'] == 'AUTH') {
                socket.add(
                  jsonEncode({'type': 'AUTH_OK', 'user_id': msg['pubkey']}),
                );
              }
            } catch (_) {}
          });
        } else {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        }
      });
    }

    setUpAll(() async {
      await startFakeRelay();
      appState = AppState();
      appState.useLocalDevRelay = true;
      appState.localDevRelayUrl = 'http://127.0.0.1:${server.port}';
      if (appState.isLocked || appState.isOnboardingRequired) {
        await appState.setupPinAndInitialize(
          pin: '1234',
          username: 'AliceUser',
          codename: 'ALICE',
          profileImage: 'alice_pic_hex',
        );
      }
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!WebSocketClient().isConnected &&
          DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      expect(WebSocketClient().isConnected, isTrue);
    });

    tearDownAll(() async {
      appState.stopConnectionWatchdog();
      WebSocketClient().disconnect();
      await server.close(force: true);
    });

    tearDown(() => WebSocketClient().onMessageSent = null);

    test(
      '1-on-1: defineEmoji writes an emoji_def into our lane and pins it',
      () async {
        final keyHash = 'c' * 64;
        await appState.addOrRechargeContact(
          'Bob',
          appState.localDevRelayUrl,
          100000,
          keyHash,
          seed,
        );
        final contact = appState.contacts.firstWhere(
          (c) => c.keyHash == keyHash,
        );
        await CustomEmojiStore.clear(keyHash);

        final sent = <Map<String, dynamic>>[];
        WebSocketClient().onMessageSent = (m) => sent.add(m);

        final err = await appState.defineEmoji(
          contact,
          _emoji('partyparrot', ts: 10),
        );
        expect(err, isNull);
        await Future.delayed(const Duration(milliseconds: 250));

        // An emoji_def message was sent to the peer (consuming our lane).
        final frame = sent.firstWhere(
          (m) =>
              m['content_type'] == 'emoji_def' && m['recipient_id'] == keyHash,
          orElse: () => {},
        );
        expect(frame, isNotEmpty);
        // ...and we pinned it locally (mesh excludes self, so it never echoes back).
        expect(
          CustomEmojiStore.cachedMap(keyHash).containsKey('partyparrot'),
          isTrue,
        );
      },
    );

    test(
      '1-on-1: an inbound emoji_def pins to the pool, not the chat stream',
      () async {
        final keyHash = 'd' * 64;
        await appState.addOrRechargeContact(
          'Carol',
          appState.localDevRelayUrl,
          100000,
          keyHash,
          seed,
        );
        final contact = appState.contacts.firstWhere(
          (c) => c.keyHash == keyHash,
        );
        await CustomEmojiStore.clear(keyHash);

        // Craft a peer-authored emoji_def at the peer's next lane offset.
        final offset = contact.incomingOffset;
        final plain = utf8.encode(
          jsonEncode(_emoji('blobwave', ts: 20).toJson()),
        );
        final cipher = await WiltkeyOtpService.xorWithKeystream(
          keyHash,
          plain,
          offset,
        );
        final env = jsonEncode({
          't': 'emoji_def',
          'd': base64Encode(cipher),
          'offset': offset,
          'id': 'edef1',
        });
        WebSocketClient().onMessageReceived!(keyHash, env, 'emoji_def');
        await Future.delayed(const Duration(milliseconds: 250));

        expect(
          CustomEmojiStore.cachedMap(keyHash).containsKey('blobwave'),
          isTrue,
        );
        // Stored (so we can serve it on resync) but tagged emoji_def → filtered from view.
        final stored = appState.messages[contact.id] ?? [];
        expect(stored.where((m) => m.contentType == 'emoji_def'), isNotEmpty);
      },
    );

    test(
      'group: an inbound member emoji_def pins for everyone (no relay needed)',
      () async {
        final groupId = 'grp_emoji_${DateTime.now().microsecondsSinceEpoch}';
        await appState.addGroupChat(
          name: 'EmojiCrew',
          groupId: groupId,
          relayUrl: appState.localDevRelayUrl,
          totalGroupSize: totalSize,
          laneSize: laneSize,
          groupIconHex: 'aabbccddeeff',
          maxMembers: maxMembers,
          groupSeed: groupSeed,
        );
        await appState.hostRegisterMember(
          groupId: groupId,
          peerId: memberA,
          peerName: 'A',
          peerProfileImage: 'a',
          slotIndex: 2,
        );
        await CustomEmojiStore.clear(groupId);

        // Member A writes an emoji_def in its own lane (slot 2), past the header.
        final offset =
            appState.laneStartFor(2, laneSize) + AppState.laneHeaderSize;
        final plain = utf8.encode(
          jsonEncode(_emoji('catjam', ts: 30).toJson()),
        );
        final cipher = await WiltkeyOtpService.xorWithGroupKeystream(
          groupId,
          plain,
          offset,
        );
        final env = jsonEncode({
          'group_id': groupId,
          'sender_id': memberA,
          'slot_index': 2,
          'offset': offset,
          'd': base64Encode(cipher),
          't': 'emoji_def',
          'id': 'gdef1',
        });
        WebSocketClient().onMessageReceived!(memberA, env, 'group_message');
        await Future.delayed(const Duration(milliseconds: 300));

        expect(
          CustomEmojiStore.cachedMap(groupId).containsKey('catjam'),
          isTrue,
        );
      },
    );

    test('resync replays an emoji_def and re-pins it', () async {
      final keyHash = 'f' * 64;
      await appState.addOrRechargeContact(
        'Dave',
        appState.localDevRelayUrl,
        100000,
        keyHash,
        seed,
      );
      final contact = appState.contacts.firstWhere((c) => c.keyHash == keyHash);
      await CustomEmojiStore.clear(keyHash);

      final offset = contact.incomingOffset + 100;
      final plain = utf8.encode(
        jsonEncode(_emoji('thumbsup', ts: 40).toJson()),
      );
      final cipher = await WiltkeyOtpService.xorWithKeystream(
        keyHash,
        plain,
        offset,
      );
      final resp = jsonEncode({
        'group_id': null,
        'messages': [
          {
            'id': 'rdef1',
            'senderId': keyHash,
            'text': base64Encode(cipher),
            'contentType': 'emoji_def',
            'timestamp': DateTime.now().toIso8601String(),
            'isSentByMe': false,
            'offset': offset,
          },
        ],
      });
      WebSocketClient().onMessageReceived!(
        keyHash,
        resp,
        'chat_resync_response',
      );
      await Future.delayed(const Duration(milliseconds: 250));

      expect(
        CustomEmojiStore.cachedMap(keyHash).containsKey('thumbsup'),
        isTrue,
      );
    });
  });
}
