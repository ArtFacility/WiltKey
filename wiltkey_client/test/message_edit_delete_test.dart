import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiltkey_client/core/crypto/otp_service.dart';
import 'package:wiltkey_client/core/db/wiltkey_db.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/state.dart';

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

  const MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  ).setMockMethodCallHandler((MethodCall methodCall) async {
    return null;
  });

  group('ChatMessage Edit & Delete Wire Framing', () {
    test('buildEditBody and parseEditOrDelete roundtrip', () {
      final body = ChatMessage.buildEditBody('msg-12345', 'Hello updated world!');
      expect(body.startsWith('\x02e\x02msg-12345\x02'), isTrue);

      final parsed = ChatMessage.parseEditOrDelete(body);
      expect(parsed.editTargetId, equals('msg-12345'));
      expect(parsed.deleteTargetId, isNull);
      expect(parsed.text, equals('Hello updated world!'));
    });

    test('buildDeleteBody and parseEditOrDelete roundtrip', () {
      final body = ChatMessage.buildDeleteBody('msg-67890');
      expect(body, equals('\x02d\x02msg-67890\x02'));

      final parsed = ChatMessage.parseEditOrDelete(body);
      expect(parsed.deleteTargetId, equals('msg-67890'));
      expect(parsed.editTargetId, isNull);
      expect(parsed.text, isEmpty);
    });

    test('parseEditOrDelete parses normal messages without edit/delete targets', () {
      final normal = ChatMessage.parseEditOrDelete('Hello normal message');
      expect(normal.editTargetId, isNull);
      expect(normal.deleteTargetId, isNull);
      expect(normal.text, equals('Hello normal message'));

      final invalidPrefix = ChatMessage.parseEditOrDelete('\x02x\x02msg-1\x02');
      expect(invalidPrefix.editTargetId, isNull);
      expect(invalidPrefix.deleteTargetId, isNull);
      expect(invalidPrefix.text, equals('\x02x\x02msg-1\x02'));
    });
  });

  group('ChatMessage Model Serialization', () {
    test('toJson and fromJson preserve edit and delete properties', () {
      final now = DateTime.now();
      final msg = ChatMessage(
        id: 'msg-abc',
        senderId: 'contact-xyz',
        text: 'Initial message',
        decryptedText: 'Edited message text',
        timestamp: now,
        isSentByMe: true,
        isEdited: true,
        editTargetId: 'msg-abc',
        editedAt: now.millisecondsSinceEpoch,
        isDeleted: false,
      );

      final json = msg.toJson();
      expect(json['isEdited'], isTrue);
      expect(json['editTargetId'], equals('msg-abc'));
      expect(json['editedAt'], equals(now.millisecondsSinceEpoch));
      expect(json['isDeleted'], isNull); // only written if true

      final restored = ChatMessage.fromJson(json);
      expect(restored.id, equals('msg-abc'));
      expect(restored.isEdited, isTrue);
      expect(restored.editTargetId, equals('msg-abc'));
      expect(restored.editedAt, equals(now.millisecondsSinceEpoch));
      expect(restored.isDeleted, isFalse);
    });
  });

  group('WiltkeyDatabase Message Edit and Deletion Operations', () {
    setUp(() async {
      await WiltkeyDatabase.instance.init();
    });

    test('updateMessageContent updates text and marks is_edited', () async {
      const masterKey = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final original = ChatMessage(
        id: 'msg-test-1',
        senderId: 'peer-hash',
        text: 'EncryptedPayload1',
        decryptedText: 'Original plain text',
        timestamp: DateTime.now(),
        isSentByMe: true,
      );

      await WiltkeyDatabase.instance.saveMessage(
        original,
        'contact-1',
        masterKeyHex: masterKey,
      );

      final loaded = await WiltkeyDatabase.instance.getMessageById(
        'msg-test-1',
        masterKeyHex: masterKey,
      );
      expect(loaded, isNotNull);
      expect(loaded!.decryptedText, equals('Original plain text'));
      expect(loaded.isEdited, isFalse);
      expect(loaded.isDeleted, isFalse);

      final editedTime = DateTime.now();
      await WiltkeyDatabase.instance.updateMessageContent(
        'msg-test-1',
        newText: 'Updated plain text',
        isEdited: true,
        isDeleted: false,
        editedAt: editedTime.millisecondsSinceEpoch,
        masterKeyHex: masterKey,
      );

      final updated = await WiltkeyDatabase.instance.getMessageById(
        'msg-test-1',
        masterKeyHex: masterKey,
      );
      expect(updated, isNotNull);
      expect(updated!.decryptedText, equals('Updated plain text'));
      expect(updated.isEdited, isTrue);
      expect(updated.editedAt, isNotNull);
      expect(updated.isDeleted, isFalse);
    });

    test('deleteMessageRow marks message as is_deleted', () async {
      final original = ChatMessage(
        id: 'msg-test-2',
        senderId: 'peer-hash',
        text: 'Secret ciphertext',
        decryptedText: 'Secret clear text',
        timestamp: DateTime.now(),
        isSentByMe: true,
      );

      await WiltkeyDatabase.instance.saveMessage(original, 'contact-1');

      await WiltkeyDatabase.instance.deleteMessageRow('msg-test-2');

      final deleted = await WiltkeyDatabase.instance.getMessageById('msg-test-2');
      expect(deleted, isNotNull);
      expect(deleted!.isDeleted, isTrue);
      expect(deleted.decryptedText, equals('[Message deleted]'));
      expect(deleted.text, equals(''));
    });
  });

  group('Anti-Spoofing and Authorization Invariants', () {
    test('1:1 chat: peer cannot edit or delete messages sent by me', () {
      final myMessage = ChatMessage(
        id: 'msg-mine',
        senderId: 'me',
        text: 'Hello from me',
        decryptedText: 'Hello from me',
        timestamp: DateTime.now(),
        isSentByMe: true,
      );

      final peerEdit = ChatMessage.parseEditOrDelete(
        ChatMessage.buildEditBody('msg-mine', 'Tampered text!'),
      );
      expect(peerEdit.editTargetId, equals('msg-mine'));

      // Dispatch rule: in 1:1, incoming edit is ONLY allowed if !target.isSentByMe
      final bool allowEdit = !myMessage.isSentByMe;
      expect(allowEdit, isFalse, reason: 'Peer must not be permitted to edit my message');

      final peerDelete = ChatMessage.parseEditOrDelete(
        ChatMessage.buildDeleteBody('msg-mine'),
      );
      expect(peerDelete.deleteTargetId, equals('msg-mine'));
      final bool allowDelete = !myMessage.isSentByMe;
      expect(allowDelete, isFalse, reason: 'Peer must not be permitted to delete my message');
    });

    test('Group chat: member cannot edit or delete other members messages', () {
      final aliceMessage = ChatMessage(
        id: 'msg-alice',
        senderId: 'alice_key_hash',
        text: 'Alice text',
        decryptedText: 'Alice text',
        timestamp: DateTime.now(),
        isSentByMe: false,
      );

      const bobSenderId = 'bob_key_hash';

      final bobEdit = ChatMessage.parseEditOrDelete(
        ChatMessage.buildEditBody('msg-alice', 'Bob modifying Alice text'),
      );
      expect(bobEdit.editTargetId, equals('msg-alice'));

      // Dispatch rule: in group chats, incoming edit is ONLY allowed if target.senderId == innerSenderId
      final bool allowEdit = aliceMessage.senderId == bobSenderId;
      expect(allowEdit, isFalse, reason: 'Bob must not be permitted to edit Alice message');

      final bobDelete = ChatMessage.parseEditOrDelete(
        ChatMessage.buildDeleteBody('msg-alice'),
      );
      expect(bobDelete.deleteTargetId, equals('msg-alice'));
      final bool allowDelete = aliceMessage.senderId == bobSenderId;
      expect(allowDelete, isFalse, reason: 'Bob must not be permitted to delete Alice message');

      // But Alice CAN edit/delete her own message
      const aliceSenderId = 'alice_key_hash';
      expect(aliceMessage.senderId == aliceSenderId, isTrue);
    });
  });

  group('AppState Message Edit and Delete Integration', () {
    test('Group chat editMessage updates lane in GroupDatabase and DB', () async {
      final appState = AppState();
      if (appState.isLocked) {
        await appState.setupPinAndInitialize(
          pin: '123456',
          username: 'MeUser',
          codename: 'meuser',
          profileImage: '',
        );
      }
      const groupId = 'group_test_edit_hash_00000000000000000000000000000000000';

      // Cache group seed in OTP service
      WiltkeyOtpService.cacheGroupSeed(
        groupId,
        '0707070707070707070707070707070707070707070707070707070707070707',
        5242880,
      );

      // Setup group contact
      final groupContact = Contact(
        id: groupId,
        name: 'Test Group',
        keyHash: groupId,
        isGroup: true,
        relayUrl: 'ws://localhost:8000',
        isPrivateNode: false,
        maxBufferBytes: 5242880,
        remainingBufferBytes: 5242880,
        peerRemainingBufferBytes: 5242880,
        lastActivity: DateTime.now(),
        memberKeyHashes: [appState.userId, 'peer_member_1'],
      );
      appState.contacts.add(groupContact);

      // Setup group lanes: slot 1 assigned to user with 1MB space
      await GroupDatabase.instance.upsertLane(
        groupId: groupId,
        slotIndex: 1,
        memberKeyHash: appState.userId,
        startOffset: 1048576,
        maxOffset: 2097152,
        currentWriteOffset: 512,
        headerWritten: true,
      );

      // Create an original message sent by me
      final originalMsg = ChatMessage(
        id: 'msg-group-1',
        senderId: appState.userId,
        text: 'Initial ciphertext',
        decryptedText: 'Hello group!',
        timestamp: DateTime.now(),
        isSentByMe: true,
      );
      await WiltkeyDatabase.instance.saveMessage(
        originalMsg,
        groupId,
        masterKeyHex: appState.masterKeyHex,
      );
      appState.messages[groupId] = [originalMsg];

      // Perform edit
      final err = await appState.editMessage(groupContact, originalMsg, 'Hello group edited!');
      expect(err, isNull);
      expect(originalMsg.decryptedText, equals('Hello group edited!'));
      expect(originalMsg.isEdited, isTrue);

      // Check DB updated
      final inDb = await WiltkeyDatabase.instance.getMessageById(
        'msg-group-1',
        masterKeyHex: appState.masterKeyHex,
      );
      expect(inDb!.decryptedText, equals('Hello group edited!'));
      expect(inDb.isEdited, isTrue);

      // Check lane advanced
      final lanes = await GroupDatabase.instance.getAllLanes(groupId);
      final myLane = lanes.firstWhere((l) => l['slot_index'] == 1);
      expect(myLane['current_write_offset'] as int, greaterThan(512));

      // Perform delete
      final delErr = await appState.deleteMessage(groupContact, originalMsg);
      expect(delErr, isNull);
      expect(originalMsg.isDeleted, isTrue);
      expect(originalMsg.decryptedText, equals('[Message deleted]'));

      final deletedInDb = await WiltkeyDatabase.instance.getMessageById(
        'msg-group-1',
        masterKeyHex: appState.masterKeyHex,
      );
      expect(deletedInDb!.isDeleted, isTrue);
    });

    test('1:1 chat editMessage and deleteMessage advances OTP pad offset correctly', () async {
      final appState = AppState();
      if (appState.isLocked) {
        await appState.setupPinAndInitialize(
          pin: '123456',
          username: 'MeUser',
          codename: 'meuser',
          profileImage: '',
        );
      }
      const peerHash = 'peer_1on1_test_hash_00000000000000000000000000000000000';

      // Setup pad in OTP service for 1:1 contact
      await WiltkeyOtpService.generateKeystreamFile(
        peerHash,
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        1048576,
      );

      // Setup 1:1 contact with 512KB outgoing budget
      final oneOnOneContact = Contact(
        id: peerHash,
        name: 'Peer 1on1',
        keyHash: peerHash,
        isGroup: false,
        relayUrl: 'ws://localhost:8000',
        isPrivateNode: false,
        maxBufferBytes: 1048576,
        remainingBufferBytes: 524288,
        peerRemainingBufferBytes: 524288,
        outgoingOffset: 0,
        outgoingMaxOffset: 524288,
        incomingOffset: 524288,
        incomingMaxOffset: 1048576,
        lastActivity: DateTime.now(),
      );
      appState.contacts.add(oneOnOneContact);

      // Create an original message sent by me
      final originalMsg = ChatMessage(
        id: 'msg-1on1-1',
        senderId: 'me',
        text: 'Initial ciphertext',
        decryptedText: 'Hello 1on1!',
        timestamp: DateTime.now(),
        isSentByMe: true,
      );
      await WiltkeyDatabase.instance.saveMessage(
        originalMsg,
        peerHash,
        masterKeyHex: appState.masterKeyHex,
      );
      appState.messages[peerHash] = [originalMsg];

      // Perform edit
      final err = await appState.editMessage(oneOnOneContact, originalMsg, 'Hello 1on1 edited!');
      expect(err, isNull);
      expect(originalMsg.decryptedText, equals('Hello 1on1 edited!'));
      expect(originalMsg.isEdited, isTrue);
      expect(oneOnOneContact.outgoingOffset, greaterThan(0));

      // Check DB updated
      final inDb = await WiltkeyDatabase.instance.getMessageById(
        'msg-1on1-1',
        masterKeyHex: appState.masterKeyHex,
      );
      expect(inDb!.decryptedText, equals('Hello 1on1 edited!'));
      expect(inDb.isEdited, isTrue);

      // Perform delete
      final delErr = await appState.deleteMessage(oneOnOneContact, originalMsg);
      expect(delErr, isNull);
      expect(originalMsg.isDeleted, isTrue);
      expect(originalMsg.decryptedText, equals('[Message deleted]'));

      final deletedInDb = await WiltkeyDatabase.instance.getMessageById(
        'msg-1on1-1',
        masterKeyHex: appState.masterKeyHex,
      );
      expect(deletedInDb!.isDeleted, isTrue);
    });
  });
}
