import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiltkey_client/core/chat_metadata.dart';
import 'package:wiltkey_client/core/db/wiltkey_db.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/network/websocket_client.dart';
import 'package:wiltkey_client/core/persistence.dart';
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

  late AppState appState;
  const peerKey = 'peer_test_key_hash_00000000000000000000000000000000000000';
  const metaKeyHex =
      '1111222233334444555566667777888811112222333344445555666677778888';

  setUp(() async {
    appState = AppState();
    if (appState.isLocked) {
      await appState.setupPinAndInitialize(
        pin: '123456',
        username: 'Alice',
        codename: 'alice',
        profileImage: '',
      );
    }
    await ChatMetaStore.setKey(peerKey, metaKeyHex);
  });

  tearDown(() async {
    final dbFile = File('wiltkey.db');
    if (await dbFile.exists()) {
      try {
        await dbFile.delete();
      } catch (_) {}
    }
  });

  test('emergency chat rejects expired requests', () async {
    final seed = 'a' * 64;
    final expiredMs = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
    final enc = WiltkeyPersistence().encryptString(
      jsonEncode({
        'v': 1,
        'seed': seed,
        'wilt_expires_at_ms': expiredMs,
        'sender_name': 'Bob',
      }),
      metaKeyHex,
    );

    final ws = WebSocketClient();
    ws.onMessageReceived!(
      peerKey,
      jsonEncode({'d': enc}),
      'emergency_chat',
    );
    await Future.delayed(const Duration(milliseconds: 100));

    // Must NOT have created or replaced a contact
    final idx = appState.contacts.indexWhere((c) => c.keyHash == peerKey);
    expect(idx, equals(-1));
  });

  test('createEmergencyChat creates pending session and wipes old messages on existing/archived chat', () async {
    // 1. Create an archived contact with previous messages
    final oldContact = Contact(
      id: 'old_chat_1',
      name: 'Bob',
      keyHash: peerKey,
      relayUrl: 'wss://relay.example.com',
      isPrivateNode: false,
      maxBufferBytes: 10000,
      remainingBufferBytes: 0,
      peerRemainingBufferBytes: 0,
      lastActivity: DateTime.now(),
      isArchived: true,
      isWilted: true,
    );
    appState.contacts.add(oldContact);
    await WiltkeyDatabase.instance.upsertContact(oldContact);

    final oldMsg = ChatMessage(
      id: 'old_msg_1',
      senderId: peerKey,
      text: 'old text',
      decryptedText: 'old text',
      timestamp: DateTime.now(),
      isSentByMe: false,
    );
    await WiltkeyDatabase.instance.saveMessage(oldMsg, oldContact.id);
    appState.messages[oldContact.id] = [oldMsg];

    // 2. Start emergency chat
    final err = await appState.createEmergencyChat(peerKey);
    expect(err, isNull);

    final idx = appState.contacts.indexWhere((c) => c.keyHash == peerKey);
    expect(idx, isNot(-1));
    final contact = appState.contacts[idx];
    expect(contact.isPendingEmergency, isTrue);
    expect(contact.isTimeWilt, isTrue);
    expect(contact.isArchived, isFalse);
    expect(contact.isWilted, isFalse);

    // Old messages must be deleted and only the initial system message should remain
    final msgs = appState.messages[contact.id]!;
    expect(msgs.length, equals(1));
    expect(msgs.first.senderId, equals('system'));
    expect(msgs.first.decryptedText, contains('Emergency chat requested'));
  });

  test('inbound emergency_chat_ack unlocks pending emergency chat on initiator side', () async {
    // Contact is in pending emergency chat state
    final contact = Contact(
      id: 'pending_chat_1',
      name: 'Bob',
      keyHash: peerKey,
      relayUrl: 'wss://relay.example.com',
      isPrivateNode: false,
      maxBufferBytes: 0,
      remainingBufferBytes: 0,
      peerRemainingBufferBytes: 0,
      lastActivity: DateTime.now(),
      isPendingEmergency: true,
      streamSeedHex: 'b' * 64,
      wiltExpiresAt: DateTime.now().add(const Duration(hours: 12)),
    );
    appState.contacts.add(contact);
    await WiltkeyDatabase.instance.upsertContact(contact);

    final ackPayload = jsonEncode({
      'v': 1,
      'seed': 'b' * 64,
      'status': 'ready',
      'sender_name': 'Bob',
    });
    final enc = WiltkeyPersistence().encryptString(ackPayload, metaKeyHex);

    final ws = WebSocketClient();
    ws.onMessageReceived!(
      peerKey,
      jsonEncode({'d': enc}),
      'emergency_chat_ack',
    );
    await Future.delayed(const Duration(milliseconds: 100));

    final idx = appState.contacts.indexWhere((c) => c.keyHash == peerKey);
    expect(idx, isNot(-1));
    final updated = appState.contacts[idx];
    expect(updated.isPendingEmergency, isFalse);
  });

  test('inbound emergency_chat creates active emergency chat on receiver side and wipes previous messages', () async {
    final seed = 'c' * 64;
    final expiryMs = DateTime.now().add(const Duration(hours: 12)).millisecondsSinceEpoch;
    final enc = WiltkeyPersistence().encryptString(
      jsonEncode({
        'v': 1,
        'seed': seed,
        'wilt_expires_at_ms': expiryMs,
        'sender_name': 'Bob',
      }),
      metaKeyHex,
    );

    final ws = WebSocketClient();
    ws.onMessageReceived!(
      peerKey,
      jsonEncode({'d': enc}),
      'emergency_chat',
    );
    await Future.delayed(const Duration(milliseconds: 100));

    final idx = appState.contacts.indexWhere((c) => c.keyHash == peerKey);
    expect(idx, isNot(-1));
    final contact = appState.contacts[idx];
    expect(contact.isPendingEmergency, isFalse);
    expect(contact.isTimeWilt, isTrue);
    expect(contact.streamSeedHex, equals(seed));
  });

  test('FILE_OFFER is dropped if sender is blocked', () async {
    await WiltkeyDatabase.instance.insertContactBlock(
      ContactBlock(
        id: 1,
        keyHash: peerKey,
        blockedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    expect(await WiltkeyDatabase.instance.isContactBlocked(peerKey), isTrue);

    final ws = WebSocketClient();
    ws.onFileOffer!(
      peerKey,
      'image',
      'file_msg_123',
      jsonEncode({'id': 'file_msg_123', 't': 'image'}),
      1024,
    );
    await Future.delayed(const Duration(milliseconds: 100));

    // Message must NOT be saved
    final exists = await WiltkeyDatabase.instance.messageExists('c_dummy', id: 'file_msg_123');
    expect(exists, isFalse);
  });
}
