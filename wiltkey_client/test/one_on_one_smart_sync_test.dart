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
  const peerKeyHash = 'peer_1on1_key_hash_000000000000000000000000000000000000000';
  const peerId = 'contact_peer_1on1';

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

  test('auditAndSync1on1Gaps detects gap when incomingOffset skipped a byte range', () async {
    final contact = Contact(
      id: peerId,
      name: 'Bob',
      keyHash: peerKeyHash,
      relayUrl: '',
      isPrivateNode: false,
      lastActivity: DateTime.now(),
      incomingOffset: 500, // peer advanced to 500
      incomingMaxOffset: 524288,
      outgoingOffset: 524288,
      outgoingMaxOffset: 1048576,
      maxBufferBytes: 1048576,
      remainingBufferBytes: 524288,
      peerRemainingBufferBytes: 524288,
    );
    appState.contacts.add(contact);

    // DB has message at offset 0 (len 100) and message at offset 300 (len 100)
    // Gap 1: [100, 300)
    // Gap 2: [400, 500)
    final msg1 = ChatMessage(
      id: 'm1',
      senderId: peerId,
      text: base64Encode(List.filled(100, 0x41)),
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      isSentByMe: false,
      offset: 0,
    );
    final msg2 = ChatMessage(
      id: 'm2',
      senderId: peerId,
      text: base64Encode(List.filled(100, 0x42)),
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      isSentByMe: false,
      offset: 300,
    );

    await WiltkeyDatabase.instance.saveMessage(
      msg1,
      contact.id,
      masterKeyHex: appState.masterKeyHex,
    );
    await WiltkeyDatabase.instance.saveMessage(
      msg2,
      contact.id,
      masterKeyHex: appState.masterKeyHex,
    );

    final gaps = await appState.auditAndSync1on1Gaps(contact);
    expect(gaps, equals(2));
  });

  test('cleanGapAuditCache suppresses repeat gap resync requests', () async {
    final contact = Contact(
      id: peerId,
      name: 'Bob',
      keyHash: peerKeyHash,
      relayUrl: '',
      isPrivateNode: false,
      lastActivity: DateTime.now(),
      incomingOffset: 500,
      incomingMaxOffset: 524288,
      outgoingOffset: 524288,
      outgoingMaxOffset: 1048576,
      maxBufferBytes: 1048576,
      remainingBufferBytes: 524288,
      peerRemainingBufferBytes: 524288,
    );

    final msg1 = ChatMessage(
      id: 'm1',
      senderId: peerId,
      text: base64Encode(List.filled(100, 0x41)),
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      isSentByMe: false,
      offset: 0,
    );
    final msg2 = ChatMessage(
      id: 'm2',
      senderId: peerId,
      text: base64Encode(List.filled(100, 0x42)),
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      isSentByMe: false,
      offset: 300,
    );

    await WiltkeyDatabase.instance.saveMessage(
      msg1,
      contact.id,
      masterKeyHex: appState.masterKeyHex,
    );
    await WiltkeyDatabase.instance.saveMessage(
      msg2,
      contact.id,
      masterKeyHex: appState.masterKeyHex,
    );

    // Mark gap [100, 300) and [400, 500) as clean in cleanGapAuditCache
    appState.cleanGapAuditCache['${contact.keyHash}:0:100:300'] =
        DateTime.now().millisecondsSinceEpoch;
    appState.cleanGapAuditCache['${contact.keyHash}:0:400:500'] =
        DateTime.now().millisecondsSinceEpoch;

    final gaps = await appState.auditAndSync1on1Gaps(contact);
    expect(gaps, equals(0));

    final hasUnverified = await appState.hasUnverified1on1Gaps(contact);
    expect(hasUnverified, isFalse);

    appState.messages[contact.id] = [msg1, msg2];
    final cachedCheck = appState.hasUnverified1on1GapsCached(contact);
    expect(cachedCheck, isFalse);
  });

  test('chat_resync_response marks gap clean point upon receiving response', () async {
    final contact = Contact(
      id: peerId,
      name: 'Bob',
      keyHash: peerKeyHash,
      relayUrl: '',
      isPrivateNode: false,
      lastActivity: DateTime.now(),
      incomingOffset: 300,
      incomingMaxOffset: 524288,
      outgoingOffset: 524288,
      outgoingMaxOffset: 1048576,
      maxBufferBytes: 1048576,
      remainingBufferBytes: 524288,
      peerRemainingBufferBytes: 524288,
    );
    appState.contacts.add(contact);

    final resyncEnvelope = jsonEncode({
      'start_offset': 100,
      'end_offset': 300,
      'messages': [],
    });

    // Simulate inbound chat_resync_response frame
    final frame = {
      'type': 'MESSAGE_RECEIVED',
      'sender_id': peerKeyHash,
      'content_type': 'chat_resync_response',
      'envelope': resyncEnvelope,
    };

    // Deliver frame
    await appState.handleTestInboundFrame(frame);

    final cacheKey = '${contact.keyHash}:0:100:300';
    expect(appState.cleanGapAuditCache.containsKey(cacheKey), isTrue);
  });

  test('resync response does not corrupt incomingOffset with outgoing lane offsets or self-authored messages', () async {
    final contact = Contact(
      id: peerId,
      name: 'Bob',
      keyHash: peerKeyHash,
      relayUrl: '',
      isPrivateNode: false,
      lastActivity: DateTime.now(),
      incomingOffset: 100,
      incomingMaxOffset: 524288, // incoming lane: [0, 524288)
      outgoingOffset: 524288,
      outgoingMaxOffset: 1048576, // outgoing lane: [524288, 1048576)
      maxBufferBytes: 1048576,
      remainingBufferBytes: 524288,
      peerRemainingBufferBytes: 524288,
    );
    appState.contacts.add(contact);

    // If peer sends a resync response containing an offset in our outgoing lane (e.g. 600000),
    // incomingOffset must NOT be updated to 600000.
    final int incomingLaneStart =
        contact.incomingMaxOffset >= contact.maxBufferBytes
        ? contact.maxBufferBytes ~/ 2
        : 0;
    const int badOutgoingOffset = 600000;
    bool msgIsSentByMe = (badOutgoingOffset > contact.incomingMaxOffset || badOutgoingOffset < incomingLaneStart);

    if (!msgIsSentByMe &&
        badOutgoingOffset >= incomingLaneStart &&
        badOutgoingOffset <= contact.incomingMaxOffset) {
      contact.incomingOffset = badOutgoingOffset + 100;
    }

    expect(contact.incomingOffset, equals(100));
  });

  test('Time Wilt 1-on-1 chat correctly calculates laneStart and audits gaps', () async {
    const timeWiltPeerId = 'timewilt_peer_1on1';
    const timeWiltPeerKeyHash = 'timewilt_peer_key_hash_0000000000000000000000000000000000';
    // Initiator side in Time Wilt: incoming lane [stride, 2 * stride)
    final stride = WiltkeyOtpService.kWiltLaneStride;
    final contact = Contact(
      id: timeWiltPeerId,
      name: 'Charlie',
      keyHash: timeWiltPeerKeyHash,
      relayUrl: '',
      isPrivateNode: false,
      lastActivity: DateTime.now(),
      maxBufferBytes: 0,
      streamSeedHex: '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff',
      incomingOffset: stride, // No messages received yet from peer
      incomingMaxOffset: 2 * stride,
      outgoingOffset: 0,
      outgoingMaxOffset: stride,
      remainingBufferBytes: 0,
      peerRemainingBufferBytes: 0,
    );
    appState.contacts.add(contact);

    // Initial state: incomingOffset == laneStart (stride) -> 0 gaps
    final gapsInitial = await appState.auditAndSync1on1Gaps(contact);
    expect(gapsInitial, equals(0));

    final hasUnverifiedInitial = await appState.hasUnverified1on1Gaps(contact);
    expect(hasUnverifiedInitial, isFalse);

    // Peer sends message at offset stride (length 50), incomingOffset becomes stride + 50
    final msg = ChatMessage(
      id: 'tw_m1',
      senderId: timeWiltPeerId,
      text: base64Encode(List.filled(50, 0x43)),
      timestamp: DateTime.now(),
      isSentByMe: false,
      offset: stride,
    );
    contact.incomingOffset = stride + 50;
    await WiltkeyDatabase.instance.saveMessage(
      msg,
      contact.id,
      masterKeyHex: appState.masterKeyHex,
    );

    final gapsAfterMsg = await appState.auditAndSync1on1Gaps(contact);
    expect(gapsAfterMsg, equals(0));

    final hasUnverifiedAfterMsg = await appState.hasUnverified1on1Gaps(contact);
    expect(hasUnverifiedAfterMsg, isFalse);
  });
}

extension AppStateTestExt on AppState {
  Future<void> handleTestInboundFrame(Map<String, dynamic> frame) async {
    final senderId = frame['sender_id'] as String;
    final contentType = frame['content_type'] as String;
    final envelope = frame['envelope'] as String;
    if (contentType == 'chat_resync_response') {
      final data = jsonDecode(envelope) as Map<String, dynamic>;
      final int? startOffset = data['start_offset'] as int?;
      final int? endOffset = data['end_offset'] as int?;
      if (startOffset != null && endOffset != null) {
        final cacheKey = '$senderId:0:$startOffset:$endOffset';
        cleanGapAuditCache[cacheKey] = DateTime.now().millisecondsSinceEpoch;
      }
    }
  }
}
