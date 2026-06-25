// Group chat PROTOCOL harness.
//
// These tests drive the REAL production code paths (AppState group logic, the
// deterministic OTP service, the SQLite group DB) — nothing about the wire
// protocol is re-implemented, so the tests can't silently drift from the app.
//
// "Peers" are simulated by:
//   * crafting the exact wire envelopes and feeding them via ws.onMessageReceived
//   * capturing the subject's outbound frames via ws.onMessageSent
//   * generating peer ciphertext with the real WiltkeyOtpService against the
//     shared groupSeed (so round-trips are byte-for-byte faithful)
//
// A tiny in-process WebSocket server completes the CHALLENGE/AUTH handshake so
// AppState reports a live connection (keeps ensureWebSocketConnected fast and
// avoids lingering reconnect timers). It does NOT route — routing is simulated
// directly through the callbacks above.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiltkey_client/core/state.dart';
import 'package:wiltkey_client/core/crypto/otp_service.dart';
import 'package:wiltkey_client/core/db/wiltkey_db.dart';
import 'package:wiltkey_client/core/network/websocket_client.dart';
import 'package:wiltkey_client/core/persistence.dart';

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

  late AppState appState;
  late HttpServer server;
  late String groupSeed;
  final String hostHash = 'e' * 64; // fake remote host id for member-side tests
  final String memberA = 'a' * 64;
  final String memberB = 'b' * 64;

  const int laneSize = 64 * 1024; // 64KB lanes keep keystream generation quick
  const int maxMembers = 4;
  final int totalSize = AppState.infoLaneSize + maxMembers * laneSize;
  const String groupIcon = 'aabbccddeeff00112233'; // stand-in pixel hex

  // --- minimal in-process relay (handshake only) -----------------------------
  Future<void> startFakeRelay() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((HttpRequest req) async {
      if (req.uri.path == '/ws' && WebSocketTransformer.isUpgradeRequest(req)) {
        final socket = await WebSocketTransformer.upgrade(req);
        socket.add(jsonEncode({'type': 'CHALLENGE', 'challenge': 'deadbeef'}));
        socket.listen((data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            if (msg['type'] == 'AUTH') {
              socket.add(
                jsonEncode({'type': 'AUTH_OK', 'user_id': msg['pubkey']}),
              );
            }
            // All other frames are intentionally ignored; routing is simulated
            // via the AppState WS callbacks in the tests.
          } catch (_) {}
        });
      } else {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    });
  }

  // Build an encrypted group_info_update envelope exactly as a peer host would.
  String buildInfoUpdateEnvelope({
    required String senderId,
    required String groupId,
    required String groupName,
    required String icon,
    required String hostKeyHash,
    required List<Map<String, dynamic>> laneAssignments,
    required List<Map<String, dynamic>> profiles,
  }) {
    final payload = jsonEncode({
      'group_name': groupName,
      'group_icon': icon,
      'lane_size': laneSize,
      'max_members': maxMembers,
      'total_size': totalSize,
      'host_key_hash': hostKeyHash,
      'lane_assignments': laneAssignments,
      'members_profiles': profiles,
    });
    final keyHex = sha256.convert(utf8.encode(groupSeed)).toString();
    final enc = WiltkeyPersistence().encryptString(payload, keyHex);
    return jsonEncode({
      'group_id': groupId,
      'sender_id': senderId,
      'd': enc,
      't': 'group_info_update',
    });
  }

  setUpAll(() async {
    await startFakeRelay();
    groupSeed = ('0123456789abcdef' * 4); // 64 hex chars

    appState = AppState();
    appState.useLocalDevRelay = true;
    appState.localDevRelayUrl = 'http://127.0.0.1:${server.port}';

    if (appState.isLocked || appState.isOnboardingRequired) {
      await appState.setupPinAndInitialize(
        pin: '1234',
        username: 'HostUser',
        codename: 'HOSTU',
        profileImage: 'host_pic_hex',
      );
    }

    // Wait for the real WS handshake to complete.
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!WebSocketClient().isConnected &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    expect(
      WebSocketClient().isConnected,
      isTrue,
      reason: 'fake relay handshake failed',
    );
  });

  tearDownAll(() async {
    appState.stopConnectionWatchdog();
    WebSocketClient().disconnect();
    await server.close(force: true);
  });

  tearDown(() {
    WebSocketClient().onMessageSent = null;
  });

  test(
    '1: spoke applies group_info_update (full host name, icon, profiles, timer cancel)',
    () async {
      final groupId = 'grp_info_${DateTime.now().microsecondsSinceEpoch}';

      await appState.addOrRechargeGroupContact(
        name: 'Placeholder',
        relayUrl: appState.localDevRelayUrl,
        totalSize: totalSize,
        laneSize: laneSize,
        groupId: groupId,
        groupSeed: groupSeed,
        slotIndex: 2,
        hostKeyHash: hostHash,
        hostName: 'HSHRT', // shortcode placeholder, should be replaced by sync
        groupIconHex: null,
      );

      // Simulate an in-flight metadata sync cycle so we can assert it gets cancelled.
      appState.groupMetaSyncTimers[groupId] = Timer(
        const Duration(seconds: 60),
        () {},
      );

      final envelope = buildInfoUpdateEnvelope(
        senderId: hostHash,
        groupId: groupId,
        groupName: 'CryptoCrew',
        icon: groupIcon,
        hostKeyHash: hostHash,
        laneAssignments: [
          {'slot_index': 1, 'member_key_hash': hostHash},
          {'slot_index': 2, 'member_key_hash': appState.userId},
        ],
        profiles: [
          {
            'key_hash': hostHash,
            'name': 'Real Host Name',
            'profile_image': 'hostpic',
            'arrival_order': 1,
          },
          {
            'key_hash': appState.userId,
            'name': 'Me',
            'profile_image': 'mypic',
            'arrival_order': 2,
          },
        ],
      );

      WebSocketClient().onMessageReceived!(
        hostHash,
        envelope,
        'group_info_update',
      );
      await Future.delayed(const Duration(milliseconds: 300));

      final contact = appState.contacts.firstWhere((c) => c.keyHash == groupId);
      expect(contact.hostName, equals('Real Host Name'));
      expect(contact.groupIconHex, equals(groupIcon));
      expect(contact.memberKeyHashes, contains(hostHash));

      final cache = appState.groupProfilesCache[contact.id];
      expect(cache, isNotNull);
      expect(cache![hostHash]?['name'], equals('Real Host Name'));

      expect(
        appState.groupMetaSyncTimers.containsKey(groupId),
        isFalse,
        reason: 'fallback timer should be cancelled once metadata arrives',
      );
    },
  );

  test(
    '2: host broadcasts correct group_info_update when a member joins',
    () async {
      final groupId = 'grp_host_${DateTime.now().microsecondsSinceEpoch}';

      await appState.addGroupChat(
        name: 'HostGroup',
        groupId: groupId,
        relayUrl: appState.localDevRelayUrl,
        totalGroupSize: totalSize,
        laneSize: laneSize,
        groupIconHex: groupIcon,
        maxMembers: maxMembers,
        groupSeed: groupSeed,
      );

      final sent = <Map<String, dynamic>>[];
      WebSocketClient().onMessageSent = (m) => sent.add(m);

      await appState.hostRegisterMember(
        groupId: groupId,
        peerId: memberA,
        peerName: 'Alice',
        peerProfileImage: 'alice_pic',
        slotIndex: 2,
      );
      await Future.delayed(const Duration(milliseconds: 300));

      final update = sent.firstWhere(
        (m) =>
            m['content_type'] == 'group_info_update' &&
            m['recipient_id'] == memberA,
        orElse: () => {},
      );
      expect(
        update,
        isNotEmpty,
        reason: 'host must broadcast metadata to the new member',
      );

      final d = jsonDecode(update['envelope'] as String)['d'] as String;
      final keyHex = sha256.convert(utf8.encode(groupSeed)).toString();
      final payload =
          jsonDecode(WiltkeyPersistence().decryptString(d, keyHex))
              as Map<String, dynamic>;

      expect(payload['host_key_hash'], equals(appState.userId));
      expect(payload['group_icon'], equals(groupIcon));

      final profiles = (payload['members_profiles'] as List)
          .cast<Map<String, dynamic>>();
      final hostProfile = profiles.firstWhere(
        (p) => p['key_hash'] == appState.userId,
      );
      expect(hostProfile['name'], equals('HostUser'));
      expect(hostProfile['profile_image'], equals('host_pic_hex'));
      final aliceProfile = profiles.firstWhere((p) => p['key_hash'] == memberA);
      expect(aliceProfile['name'], equals('Alice'));
      expect(aliceProfile['arrival_order'], equals(2));

      final lanes = (payload['lane_assignments'] as List)
          .cast<Map<String, dynamic>>();
      expect(
        lanes.any(
          (l) => l['slot_index'] == 2 && l['member_key_hash'] == memberA,
        ),
        isTrue,
      );
    },
  );

  test(
    '3: host receives a member lane-header + message, decrypts, and ACKs',
    () async {
      final groupId = 'grp_recv_${DateTime.now().microsecondsSinceEpoch}';
      await appState.addGroupChat(
        name: 'RecvGroup',
        groupId: groupId,
        relayUrl: appState.localDevRelayUrl,
        totalGroupSize: totalSize,
        laneSize: laneSize,
        groupIconHex: groupIcon,
        maxMembers: maxMembers,
        groupSeed: groupSeed,
      );
      final contact = appState.contacts.firstWhere((c) => c.keyHash == groupId);

      final sent = <Map<String, dynamic>>[];
      WebSocketClient().onMessageSent = (m) => sent.add(m);

      // Member A occupies slot 2. Craft its lane header + message with the SHARED keystream.
      final laneStart = appState.laneStartFor(2, laneSize);

      final headerBytes = appState.buildLaneHeader(
        name: 'Alice',
        profileImage: 'alice_pic',
        arrivalOrder: 2,
      );
      final headerCipher = await WiltkeyOtpService.xorWithGroupKeystream(
        groupId,
        headerBytes,
        laneStart,
      );
      final headerEnv = jsonEncode({
        'group_id': groupId,
        'sender_id': memberA,
        'slot_index': 2,
        'offset': laneStart,
        'd': base64Encode(headerCipher),
        't': 'group_lane_header',
      });
      WebSocketClient().onMessageReceived!(memberA, headerEnv, 'group_message');
      await Future.delayed(const Duration(milliseconds: 200));

      const text = 'hi from alice';
      final msgOffset = laneStart + AppState.laneHeaderSize;
      final msgCipher = await WiltkeyOtpService.xorWithGroupKeystream(
        groupId,
        utf8.encode(text),
        msgOffset,
      );
      final msgEnv = jsonEncode({
        'group_id': groupId,
        'sender_id': memberA,
        'slot_index': 2,
        'offset': msgOffset,
        'd': base64Encode(msgCipher),
        't': 'text',
        'id': 'm1',
      });
      WebSocketClient().onMessageReceived!(memberA, msgEnv, 'group_message');
      await Future.delayed(const Duration(milliseconds: 300));

      // Profile learned from the lane header.
      final profile = await GroupDatabase.instance.getProfile(groupId, memberA);
      expect(profile?['name'], equals('Alice'));

      // Message decrypted + appended.
      final msgs = appState.messages[contact.id] ?? [];
      final received = msgs.firstWhere(
        (m) => m.id == 'm1',
        orElse: () => throw 'message not appended',
      );
      expect(received.decryptedText, equals(text));
      expect(received.senderId, equals(memberA));

      // Delivery receipt emitted back to the sender.
      final receipt = sent.firstWhere(
        (m) =>
            m['content_type'] == 'delivery_receipt' &&
            m['recipient_id'] == memberA,
        orElse: () => {},
      );
      expect(receipt, isNotEmpty);
      expect(
        jsonDecode(receipt['envelope'] as String)['message_id'],
        equals('m1'),
      );
    },
  );

  test(
    '4: full mesh — host send broadcasts to every member at the right offset',
    () async {
      final groupId = 'grp_mesh_${DateTime.now().microsecondsSinceEpoch}';
      await appState.addGroupChat(
        name: 'MeshGroup',
        groupId: groupId,
        relayUrl: appState.localDevRelayUrl,
        totalGroupSize: totalSize,
        laneSize: laneSize,
        groupIconHex: groupIcon,
        maxMembers: maxMembers,
        groupSeed: groupSeed,
      );
      await appState.hostRegisterMember(
        groupId: groupId,
        peerId: memberA,
        peerName: 'Alice',
        peerProfileImage: 'a',
        slotIndex: 2,
      );
      await appState.hostRegisterMember(
        groupId: groupId,
        peerId: memberB,
        peerName: 'Bob',
        peerProfileImage: 'b',
        slotIndex: 3,
      );

      appState.activeContact = appState.contacts.firstWhere(
        (c) => c.keyHash == groupId,
      );

      final sent = <Map<String, dynamic>>[];
      WebSocketClient().onMessageSent = (m) => sent.add(m);

      final err = await appState.sendGroupMessage('hello group');
      expect(err, isNull);
      await Future.delayed(const Duration(milliseconds: 200));

      final msgFrames = sent
          .where((m) => m['content_type'] == 'group_message')
          .toList();
      final recipients = msgFrames.map((m) => m['recipient_id']).toSet();
      expect(recipients, containsAll(<String>[memberA, memberB]));

      // Host writes in its own lane (slot 1); message follows the 512B header.
      final expectedOffset =
          appState.laneStartFor(1, laneSize) + AppState.laneHeaderSize;
      final frame =
          jsonDecode(msgFrames.first['envelope'] as String)
              as Map<String, dynamic>;
      expect(frame['slot_index'], equals(1));
      expect(frame['offset'], equals(expectedOffset));
    },
  );

  test(
    '5: a non-host member answers a metadata request (host-offline fallback)',
    () async {
      final groupId = 'grp_fallback_${DateTime.now().microsecondsSinceEpoch}';
      await appState.addOrRechargeGroupContact(
        name: 'FallbackGroup',
        relayUrl: appState.localDevRelayUrl,
        totalSize: totalSize,
        laneSize: laneSize,
        groupId: groupId,
        groupSeed: groupSeed,
        slotIndex: 3,
        hostKeyHash: hostHash,
        hostName: 'Host',
        groupIconHex: groupIcon,
      );
      // We (a member) already know fellow member "memberA".
      await GroupDatabase.instance.upsertProfile(
        groupId: groupId,
        memberKeyHash: memberA,
        name: 'Alice',
        profileImage: 'a',
        arrivalOrder: 2,
      );

      final sent = <Map<String, dynamic>>[];
      WebSocketClient().onMessageSent = (m) => sent.add(m);

      // memberA asks us for metadata (the host is offline).
      WebSocketClient().onMessageReceived!(
        memberA,
        jsonEncode({'group_id': groupId}),
        'group_metadata_request',
      );
      await Future.delayed(const Duration(milliseconds: 300));

      final reply = sent.firstWhere(
        (m) =>
            m['content_type'] == 'group_info_update' &&
            m['recipient_id'] == memberA,
        orElse: () => {},
      );
      expect(
        reply,
        isNotEmpty,
        reason: 'a member that knows the requester must answer metadata',
      );
    },
  );

  test(
    '6: resync attributes messages to the real author and orders by timestamp',
    () async {
      final groupId = 'grp_resync_${DateTime.now().microsecondsSinceEpoch}';
      await appState.addOrRechargeGroupContact(
        name: 'ResyncGroup',
        relayUrl: appState.localDevRelayUrl,
        totalSize: totalSize,
        laneSize: laneSize,
        groupId: groupId,
        groupSeed: groupSeed,
        slotIndex: 3, // our own lane
        hostKeyHash: hostHash,
        hostName: 'Host',
        groupIconHex: groupIcon,
      );
      final contact = appState.contacts.firstWhere((c) => c.keyHash == groupId);

      // Craft two messages with the SHARED keystream:
      //  - one authored by memberA (slot 2), older timestamp
      //  - one authored by US (slot 3), newer timestamp — pulled back from a peer
      final offA = appState.laneStartFor(2, laneSize) + AppState.laneHeaderSize;
      final cipherA = await WiltkeyOtpService.xorWithGroupKeystream(
        groupId,
        utf8.encode('from alice'),
        offA,
      );

      final offMe =
          appState.laneStartFor(3, laneSize) + AppState.laneHeaderSize;
      final cipherMe = await WiltkeyOtpService.xorWithGroupKeystream(
        groupId,
        utf8.encode('my own msg'),
        offMe,
      );

      final response = jsonEncode({
        'group_id': groupId,
        'messages': [
          {
            'id': 'a1',
            'senderId': memberA,
            'text': base64Encode(cipherA),
            'contentType': 'text',
            'timestamp': DateTime.utc(2020, 1, 1).toIso8601String(),
            'isSentByMe': true, // peer's perspective flag — must be ignored
            'offset': offA,
          },
          {
            'id': 'me1',
            'senderId': appState.userId, // a peer echoing OUR message back
            'text': base64Encode(cipherMe),
            'contentType': 'text',
            'timestamp': DateTime.utc(2021, 1, 1).toIso8601String(),
            'isSentByMe': false,
            'offset': offMe,
          },
        ],
      });

      WebSocketClient().onMessageReceived!(
        memberA,
        response,
        'chat_resync_response',
      );
      await Future.delayed(const Duration(milliseconds: 300));

      final msgs = appState.messages[contact.id] ?? [];
      final fromAlice = msgs.firstWhere((m) => m.id == 'a1');
      final ownMsg = msgs.firstWhere((m) => m.id == 'me1');

      // Attribution: alice's message is hers (not ours); our echoed message is ours.
      expect(fromAlice.senderId, equals(memberA));
      expect(fromAlice.isSentByMe, isFalse);
      expect(fromAlice.decryptedText, equals('from alice'));

      expect(ownMsg.senderId, equals('me'));
      expect(ownMsg.isSentByMe, isTrue);
      expect(ownMsg.decryptedText, equals('my own msg'));

      // Ordering: older (2020) before newer (2021), by timestamp not arrival.
      expect(msgs.indexOf(fromAlice) < msgs.indexOf(ownMsg), isTrue);
    },
  );
}
