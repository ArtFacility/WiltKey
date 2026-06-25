import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiltkey_client/core/state.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/crypto/otp_service.dart';
import 'package:wiltkey_client/core/db/wiltkey_db.dart';
import 'package:wiltkey_client/core/network/websocket_client.dart';

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

  // Initialize ffi for SQLite database tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Mock path_provider
  PathProviderPlatform.instance = MockPathProviderPlatform();

  // Mock SharedPreferences
  const MethodChannel(
    'plugins.flutter.io/shared_preferences',
  ).setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'getAll') {
      return <String, dynamic>{};
    }
    return true;
  });

  group('Shared Pad with Lanes Group Chat Architecture Tests', () {
    final String groupId = 'test_group_id';
    final String groupSeed =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    final int totalSize = 4096 + 2 * 1024 * 1024; // info lane + 2 lanes of 1MB

    test(
      '6.1: N clients generate identical keystream from same seed',
      () async {
        final file1 = await WiltkeyOtpService.generateGroupKeystream(
          'client1_$groupId',
          groupSeed,
          totalSize,
        );
        final file2 = await WiltkeyOtpService.generateGroupKeystream(
          'client2_$groupId',
          groupSeed,
          totalSize,
        );

        expect(await file1.exists(), isTrue);
        expect(await file2.exists(), isTrue);

        final bytes1 = await file1.readAsBytes();
        final bytes2 = await file2.readAsBytes();

        expect(bytes1.length, equals(totalSize));
        expect(bytes2.length, equals(totalSize));
        expect(bytes1, equals(bytes2));

        // Cleanup
        await WiltkeyOtpService.deleteGroupKeystreamFile('client1_$groupId');
        await WiltkeyOtpService.deleteGroupKeystreamFile('client2_$groupId');
      },
    );

    test('6.2: Random Access Keystream Decryption (Lanes boundary)', () async {
      // Generate a keystream file
      await WiltkeyOtpService.generateGroupKeystream(
        groupId,
        groupSeed,
        totalSize,
      );

      final originalMessage = 'Hello, secure lane world!';
      final rawBytes = utf8.encode(originalMessage);

      // Encrypt at offset 5000 (which is in slot 1)
      final offset = 5000;
      final cipherBytes = await WiltkeyOtpService.xorWithGroupKeystream(
        groupId,
        rawBytes,
        offset,
      );

      // Decrypt at same offset
      final decryptedBytes = await WiltkeyOtpService.xorWithGroupKeystream(
        groupId,
        cipherBytes,
        offset,
      );
      final decryptedMessage = utf8.decode(decryptedBytes);

      expect(decryptedMessage, equals(originalMessage));

      // Cleanup
      await WiltkeyOtpService.deleteGroupKeystreamFile(groupId);
    });

    test('6.3: SQLite GroupDatabase operations (real SQLite ffi)', () async {
      final db = GroupDatabase.instance;
      await db.init();

      // Test upsertGroupInfo
      await db.upsertGroupInfo(
        groupId: groupId,
        groupName: 'Test Shared Pad Group',
        groupIcon: 'AABB',
        laneSize: 1000,
        maxMembers: 10,
        totalSize: 10000,
        groupSeedEncrypted: 'seed',
        isHost: true,
        hostKeyHash: 'host_id',
      );

      final info = await db.getGroupInfo(groupId);
      expect(info, isNotNull);
      expect(info!['group_name'], equals('Test Shared Pad Group'));
      expect(info['lane_size'], equals(1000));

      // Test upsertLane and assignLaneToMember
      await db.upsertLane(
        groupId: groupId,
        slotIndex: 1,
        startOffset: 4096,
        maxOffset: 5096,
        memberKeyHash: null,
      );

      final emptyLanesBefore = await db.getEmptyLanes(groupId);
      expect(emptyLanesBefore.length, equals(1));

      await db.assignLaneToMember(groupId, 1, 'spoke_1');
      final emptyLanesAfter = await db.getEmptyLanes(groupId);
      expect(emptyLanesAfter.length, equals(0));

      final lane = await db.getLane(groupId, 1);
      expect(lane!['member_key_hash'], equals('spoke_1'));

      // Test upsertProfile
      await db.upsertProfile(
        groupId: groupId,
        memberKeyHash: 'spoke_1',
        name: 'Alice',
        profileImage: 'alice_pic',
        arrivalOrder: 2,
      );

      final profile = await db.getProfile(groupId, 'spoke_1');
      expect(profile!['name'], equals('Alice'));

      // Cleanup
      await db.deleteGroup(groupId);
      final deletedInfo = await db.getGroupInfo(groupId);
      expect(deletedInfo, isNull);
    });

    test(
      '6.4: 1-on-1 Chat Resync Gap Detection and Healing (Zero OTP Keystream Waste)',
      () async {
        final appState = AppState();
        if (appState.isLocked) {
          await appState.setupPinAndInitialize(
            pin: '1234',
            username: 'Alice',
            codename: 'ALICE',
            profileImage: 'avatar_hex',
          );
        }

        // 1. Create a mock contact Bob
        final bobKeyHash = 'bob_key_hash_123';
        final String bobSeed =
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
        final int bufferSize = 10000;

        await appState.addOrRechargeContact(
          'Bob',
          'http://localhost:8000',
          bufferSize,
          bobKeyHash,
          bobSeed,
        );

        final contact = appState.contacts.firstWhere(
          (c) => c.keyHash == bobKeyHash,
        );
        expect(contact, isNotNull);

        // Verify initial incoming offset
        final initialIncomingOffset = contact.incomingOffset;
        final gapStart = initialIncomingOffset;
        final gapEnd = initialIncomingOffset + 50;

        // 2. Intercept WebSocket outgoing messages
        final ws = WebSocketClient();
        final List<Map<String, dynamic>> sentMessages = [];
        ws.onMessageSent = (msg) {
          sentMessages.add(msg);
        };

        // 3. Simulate receiving a message at a future offset (causing a gap)
        // Expected incoming offset is gapStart. We receive a message at offset gapEnd.
        final textMsg = 'Hello Alice!';
        final plainBytes = utf8.encode(textMsg);
        // Deterministically encrypt the message using the keystream at gapEnd
        final cipherBytes = await WiltkeyOtpService.xorWithKeystream(
          bobKeyHash,
          plainBytes,
          gapEnd,
        );
        final cipherB64 = base64Encode(cipherBytes);
        final messageId = 'msg_id_101';

        final envelope = jsonEncode({
          't': 'text',
          'd': cipherB64,
          'offset': gapEnd,
          'id': messageId,
        });

        // Deliver this message. This should trigger gap detection for [gapStart, gapEnd]
        ws.onMessageReceived!(bobKeyHash, envelope, 'text');

        // Wait for async operations
        await Future.delayed(const Duration(milliseconds: 100));

        // 4. Assert that a resync request was sent for the gap [gapStart, gapEnd]
        expect(sentMessages, isNotEmpty);
        final resyncRequest = sentMessages.firstWhere(
          (m) => m['content_type'] == 'chat_resync_request',
        );
        expect(resyncRequest, isNotNull);
        expect(resyncRequest['type'], equals('SEND_MESSAGE'));
        expect(resyncRequest['recipient_id'], equals(bobKeyHash));

        final requestEnvelope =
            jsonDecode(resyncRequest['envelope']) as Map<String, dynamic>;
        expect(requestEnvelope['start_offset'], equals(gapStart));
        expect(requestEnvelope['end_offset'], equals(gapEnd));
        expect(requestEnvelope['group_id'], isNull);

        // 5. Simulate Bob replying with a resync response containing the missed message
        // Bob encrypts the missed message 'Missed hello!' at offset gapStart
        final missedText = 'Missed hello!';
        final missedPlainBytes = utf8.encode(missedText);
        final missedCipher = await WiltkeyOtpService.xorWithKeystream(
          bobKeyHash,
          missedPlainBytes,
          gapStart,
        );
        final missedCipherB64 = base64Encode(missedCipher);
        final missedMsgId = 'msg_id_100';

        final responseEnvelope = jsonEncode({
          'group_id': null,
          'messages': [
            {
              'id': missedMsgId,
              'senderId': bobKeyHash,
              'text': missedCipherB64,
              'contentType': 'text',
              'timestamp': DateTime.now().toIso8601String(),
              'isSentByMe': false,
              'offset': gapStart,
            },
          ],
        });

        // Deliver resync response
        ws.onMessageReceived!(
          bobKeyHash,
          responseEnvelope,
          'chat_resync_response',
        );
        await Future.delayed(const Duration(milliseconds: 100));

        // 6. Assert that the gap is healed
        final chatMessages = appState.messages[contact.id] ?? [];
        // We expect 3 messages: the initial system message, the missed message (offset gapStart), and the future message (offset gapEnd).
        expect(chatMessages.length, equals(3));

        // Sorted chronologically by timestamp, the missed message should be before the future one
        final recoveredMsg = chatMessages.firstWhere(
          (m) => m.id == missedMsgId,
        );
        expect(recoveredMsg.decryptedText, equals(missedText));
        expect(recoveredMsg.isDelivered, isTrue);

        final futureMsg = chatMessages.firstWhere((m) => m.id == messageId);
        expect(futureMsg.decryptedText, equals(textMsg));

        // incomingOffset should be advanced to Bob's latest offset (gapEnd + cipher length)
        expect(contact.incomingOffset, equals(gapEnd + cipherBytes.length));

        // Cleanup
        ws.onMessageSent = null;
        await WiltkeyOtpService.deleteKeystreamFile(bobKeyHash);
      },
    );

    test('6.5: Delivery Receipt Toggle and UI State Update', () async {
      final appState = AppState();
      if (appState.isLocked) {
        await appState.setupPinAndInitialize(
          pin: '1234',
          username: 'Alice',
          codename: 'ALICE',
          profileImage: 'avatar_hex',
        );
      }

      final bobKeyHash = 'bob_key_hash_456';
      await appState.addOrRechargeContact(
        'Bob',
        'http://localhost:8000',
        10000,
        bobKeyHash,
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      );

      final contact = appState.contacts.firstWhere(
        (c) => c.keyHash == bobKeyHash,
      );
      final list = appState.messages[contact.id] ?? [];

      // Add a sent message to the list
      final messageId = 'sent_msg_999';
      final sentMsg = ChatMessage(
        id: messageId,
        senderId: 'me',
        text: 'base64_ciphertext',
        contentType: 'text',
        timestamp: DateTime.now(),
        isSentByMe: true,
        offset: 100,
        isDelivered: false,
      );
      appState.messages[contact.id] = [...list, sentMsg];

      final ws = WebSocketClient();
      // Deliver a delivery receipt for this message
      final receiptEnvelope = jsonEncode({
        'group_id': null,
        'message_id': messageId,
        'offset': 100,
      });

      ws.onMessageReceived!(bobKeyHash, receiptEnvelope, 'delivery_receipt');
      await Future.delayed(const Duration(milliseconds: 500));

      final updatedMsg = appState.messages[contact.id]!.firstWhere(
        (m) => m.id == messageId,
      );
      expect(updatedMsg.isDelivered, isTrue);

      await WiltkeyOtpService.deleteKeystreamFile(bobKeyHash);
    });
  });
}
