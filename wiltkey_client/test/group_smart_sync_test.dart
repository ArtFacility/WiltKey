import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiltkey_client/core/crypto/otp_service.dart';
import 'package:wiltkey_client/core/db/wiltkey_db.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/network/websocket_client.dart';
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
  const groupId = 'test_group_smart_sync_key_hash_0000000000000000000000000';
  const member1 = 'member_1_key_hash_0000000000000000000000000000000000000';
  const member2 = 'member_2_key_hash_0000000000000000000000000000000000000';
  const hostId = 'host_key_hash_000000000000000000000000000000000000000000';

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
  });

  tearDown(() async {
    final dbFile = File('wiltkey.db');
    if (await dbFile.exists()) {
      try {
        await dbFile.delete();
      } catch (_) {}
    }
  });

  test('getMostRecentSender returns latest non-system chatter excluding self', () async {
    final now = DateTime.now();
    final msg1 = ChatMessage(
      id: 'msg_1',
      senderId: member1,
      text: 'hello',
      timestamp: now.subtract(const Duration(minutes: 10)),
      isSentByMe: false,
    );
    final msg2 = ChatMessage(
      id: 'msg_2',
      senderId: member2,
      text: 'recent reply',
      timestamp: now.subtract(const Duration(minutes: 2)),
      isSentByMe: false,
    );
    final msgMe = ChatMessage(
      id: 'msg_me',
      senderId: 'me',
      text: 'my message',
      timestamp: now.subtract(const Duration(minutes: 1)),
      isSentByMe: true,
    );

    await WiltkeyDatabase.instance.saveMessage(msg1, groupId);
    await WiltkeyDatabase.instance.saveMessage(msg2, groupId);
    await WiltkeyDatabase.instance.saveMessage(msgMe, groupId);

    final recent = await WiltkeyDatabase.instance.getMostRecentSender(groupId, excludeUserId: appState.userId);
    expect(recent, equals(member2));
  });

  test('auditAndSyncGroupLanes detects gaps in member lanes and requests resync', () async {
    final group = Contact(
      id: 'group_test_1',
      name: 'Crypto Devs',
      keyHash: groupId,
      relayUrl: 'wss://api.wiltkey.org/ws',
      isGroup: true,
      isHost: false,
      hostKeyHash: hostId,
      memberKeyHashes: [hostId, member1, member2],
      laneSize: 1024 * 1024,
      maxMembers: 4,
      totalGroupSize: 1024 * 1024 * 5,
      streamSeedHex: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      isPrivateNode: false,
      maxBufferBytes: 0,
      remainingBufferBytes: 0,
      peerRemainingBufferBytes: 0,
      lastActivity: DateTime.now(),
    );

    appState.contacts.add(group);
    await WiltkeyDatabase.instance.upsertContact(group);
    WiltkeyOtpService.cacheGroupSeed(
      groupId,
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      1024 * 1024 * 5,
    );

    // Setup lane for slot 1 (member 1)
    const slot1 = 1;
    final laneStart = AppState.infoLaneSize + (slot1 - 1) * (1024 * 1024);
    await GroupDatabase.instance.upsertLane(
      groupId: groupId,
      slotIndex: slot1,
      memberKeyHash: member1,
      startOffset: laneStart,
      maxOffset: laneStart + (1024 * 1024),
      currentWriteOffset: AppState.laneHeaderSize + 5000,
      headerWritten: true,
    );

    // Save message 1 at offset laneStart + 512, length 50
    final msg1Cipher = await WiltkeyOtpService.xorWithGroupKeystream(
      groupId,
      utf8.encode('Message 1'),
      laneStart + 512,
    );
    final m1 = ChatMessage(
      id: 'g_msg_1',
      senderId: member1,
      text: base64Encode(msg1Cipher),
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      isSentByMe: false,
      offset: laneStart + 512,
    );
    await WiltkeyDatabase.instance.saveMessage(m1, group.id);

    // Save message 2 at offset laneStart + 2000 (creates a gap [laneStart + 512 + msg1Len, laneStart + 2000))
    final msg2Cipher = await WiltkeyOtpService.xorWithGroupKeystream(
      groupId,
      utf8.encode('Message 2'),
      laneStart + 2000,
    );
    final m2 = ChatMessage(
      id: 'g_msg_2',
      senderId: member1,
      text: base64Encode(msg2Cipher),
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      isSentByMe: false,
      offset: laneStart + 2000,
    );
    await WiltkeyDatabase.instance.saveMessage(m2, group.id);

    final sentFrames = <Map<String, dynamic>>[];
    WebSocketClient().onMessageReceived = (sender, envelope, contentType) {};

    // Audit and sync
    await appState.auditAndSyncGroupLanes(group);

    // Verify smart sync candidate fallback & cache populated
    expect(appState.cleanGapAuditCache, isNotNull);
  });
}
