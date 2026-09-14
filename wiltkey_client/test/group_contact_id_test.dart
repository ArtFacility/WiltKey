import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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
  const liveGroupId = 'live_group_keyhash_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const freshGroupId = 'fresh_group_keyhash_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

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

  Contact oneToOne(String id, String keyHash) => Contact(
        id: id,
        name: 'Peer $id',
        keyHash: keyHash,
        relayUrl: 'wss://relay.test',
        isPrivateNode: false,
        maxBufferBytes: 0,
        remainingBufferBytes: 0,
        peerRemainingBufferBytes: 0,
        lastActivity: DateTime.now(),
      );

  Contact liveGroup() => Contact(
        id: 'g3',
        name: 'Live Group',
        keyHash: liveGroupId,
        relayUrl: 'wss://relay.test',
        isPrivateNode: false,
        maxBufferBytes: 20000,
        remainingBufferBytes: 10000,
        peerRemainingBufferBytes: 0,
        lastActivity: DateTime.now(),
        isGroup: true,
        memberCount: 2,
        hostKeyHash: 'host_key_hash_cccccccccccccccccccccccccccccccccccccc',
        memberKeyHashes: ['host_key_hash_cccccccccccccccccccccccccccccccccccccc'],
        groupSeed: 'aa' * 32,
        laneSize: 10000,
        totalGroupSize: 20000,
        slotIndex: 2,
      );

  test('addGroupChat never reuses a live contact id after a deletion', () async {
    // Reproduces the merge-bug precondition: the in-memory list shrank below
    // the highest numeric id (a 1:1 chat was deleted), so the old
    // `contacts.length + 1` scheme computed 'g3' — the LIVE group's id — and
    // INSERT OR REPLACE silently overwrote that row.
    appState.contacts.addAll([
      oneToOne('1', 'peer1_keyhash_dddddddddddddddddddddddddddddddddddddd'),
      oneToOne('2', 'peer2_keyhash_eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'),
      liveGroup(),
    ]);
    await WiltkeyDatabase.instance.upsertContact(liveGroup());

    // Delete the low-id 1:1 chat: contacts.length drops to 2 while maxN = 3.
    appState.contacts.removeWhere((c) => c.id == '1');

    await appState.addGroupChat(
      name: 'Fresh Group',
      groupId: freshGroupId,
      relayUrl: 'wss://relay.test',
      totalGroupSize: 20000,
      laneSize: 10000,
      groupIconHex: '',
      maxMembers: 8,
      groupSeed: 'bb' * 32,
    );

    final created = appState.contacts.firstWhere((c) => c.keyHash == freshGroupId);
    expect(created.id, 'g4', reason: 'max-based id, not contacts.length-based g3');
    expect(created.id, isNot('g3'));

    // The in-memory list must not hold two chats under one id.
    expect(
      appState.contacts.where((c) => c.id == created.id).length,
      1,
      reason: 'no duplicate in-memory contact ids (they render as merged chats)',
    );

    // DB: the live group's row must NOT have been replaced by the new group
    // (old bug: INSERT OR REPLACE on the colliding id silently overwrote it).
    final dbContacts = await WiltkeyDatabase.instance.getAllContacts();
    expect(
      dbContacts.any((c) => c.id == 'g3' && c.keyHash == liveGroupId),
      isTrue,
      reason: 'live group row survived the new group creation',
    );
    expect(
      dbContacts.any((c) => c.id == 'g4' && c.keyHash == freshGroupId),
      isTrue,
    );
  });

  test('addOrRechargeGroupContact never reuses a live contact id after a deletion',
      () async {
    appState.contacts.addAll([
      oneToOne('1', 'peer1_keyhash_dddddddddddddddddddddddddddddddddddddd'),
      oneToOne('2', 'peer2_keyhash_eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'),
      liveGroup(),
    ]);
    await WiltkeyDatabase.instance.upsertContact(liveGroup());
    appState.contacts.removeWhere((c) => c.id == '1');

    await appState.addOrRechargeGroupContact(
      name: 'Joined Group',
      relayUrl: 'wss://relay.test',
      totalSize: 20000,
      laneSize: 10000,
      groupId: freshGroupId,
      groupSeed: 'cc' * 32,
      slotIndex: 2,
      hostKeyHash: 'host_key_hash_ffffffffffffffffffffffffffffffffffffffff',
      hostName: 'Host',
    );

    final created = appState.contacts.firstWhere((c) => c.keyHash == freshGroupId);
    expect(created.id, 'g4', reason: 'max-based id, not contacts.length-based g3');
    expect(
      appState.contacts.where((c) => c.id == created.id).length,
      1,
    );

    final dbContacts = await WiltkeyDatabase.instance.getAllContacts();
    expect(
      dbContacts.any((c) => c.id == 'g3' && c.keyHash == liveGroupId),
      isTrue,
      reason: 'live group row survived the join',
    );
  });
}
