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
  const peerKey = 'peer_sync_test_key_hash_00000000000000000000000000000000000000';
  const metaKeyHex =
      '2222333344445555666677778888999922223333444455556666777788889999';

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

  test('updateOwnStatus enforces 100 character limit and sets emoji and expiry', () async {
    final longStatus = 'A' * 150;
    final expiryMs = DateTime.now().add(const Duration(hours: 4)).millisecondsSinceEpoch;
    await appState.updateOwnStatus(longStatus, emoji: '⚡', expiresAtMs: expiryMs);

    expect(appState.statusMessage.length, equals(100));
    expect(appState.statusMessage, equals('A' * 100));
    expect(appState.statusEmoji, equals('⚡'));
    expect(appState.statusExpiresAtMs, equals(expiryMs));
    expect(appState.isOwnStatusExpired, isFalse);
    expect(appState.effectiveStatusMessage, equals('A' * 100));
    expect(appState.effectiveStatusEmoji, equals('⚡'));
  });

  test('expired status returns empty/null via getters', () async {
    final pastExpiry = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
    await appState.updateOwnStatus('Old status', emoji: '💤', expiresAtMs: pastExpiry);

    expect(appState.isOwnStatusExpired, isTrue);
    expect(appState.effectiveStatusMessage, isEmpty);
    expect(appState.effectiveStatusEmoji, isEmpty);

    final contact = SocialContact(
      id: 1,
      keyHash: peerKey,
      name: 'Bob',
      sharedSecretSeed: 'seed123',
      myPubkey: 'pub1',
      peerPubkey: 'pub2',
      addedAt: DateTime.now().millisecondsSinceEpoch,
      status: 'Expired message',
      statusEmoji: '🌙',
      statusExpiresAt: pastExpiry,
    );

    expect(contact.isStatusExpired, isTrue);
    expect(contact.activeStatus, isNull);
    expect(contact.activeStatusEmoji, isNull);
  });

  test('inbound profile_update instantly updates SocialContact and 1:1 Contact', () async {
    // 1. Setup existing SocialContact and Contact
    final sc = SocialContact(
      id: 1,
      keyHash: peerKey,
      name: 'Bob Initial',
      shortNick: 'BOB',
      profileImageB64: '',
      avatarBorderId: null,
      themeId: 'cyberpunk',
      sharedSecretSeed: 'seed123',
      myPubkey: 'pub1',
      peerPubkey: 'pub2',
      addedAt: DateTime.now().millisecondsSinceEpoch,
      status: null,
    );
    appState.socialContacts = [sc];
    await WiltkeyDatabase.instance.insertSocialContact(sc);

    final chatContact = Contact(
      id: 'chat_bob_1',
      name: 'Bob Initial',
      keyHash: peerKey,
      relayUrl: 'wss://relay.example.com',
      isPrivateNode: false,
      maxBufferBytes: 1000,
      remainingBufferBytes: 1000,
      peerRemainingBufferBytes: 1000,
      lastActivity: DateTime.now(),
    );
    appState.contacts.add(chatContact);
    await WiltkeyDatabase.instance.upsertContact(chatContact);

    // 2. Peer sends profile_update with updated name, nick, status, emoji, border, theme
    final expiryMs = DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch;
    final payload = jsonEncode({
      'v': 1,
      'name': 'Bob Renamed',
      'short_nick': 'BOBBY',
      'status': 'Coding secure crypto',
      'status_emoji': '🚀',
      'status_expires_at_ms': expiryMs,
      'theme_id': 'garden',
      'avatar_border_id': 'neon_pulse',
      'profile_image_b64': '01020304',
    });

    final enc = WiltkeyPersistence().encryptString(payload, metaKeyHex);
    final ws = WebSocketClient();
    ws.onMessageReceived!(
      peerKey,
      jsonEncode({'d': enc}),
      'profile_update',
    );
    await Future.delayed(const Duration(milliseconds: 100));

    // 3. SocialContact in memory must be updated
    final updatedSc = appState.socialContacts.firstWhere((c) => c.keyHash == peerKey);
    expect(updatedSc.name, equals('Bob Renamed'));
    expect(updatedSc.shortNick, equals('BOBBY'));
    expect(updatedSc.status, equals('Coding secure crypto'));
    expect(updatedSc.statusEmoji, equals('🚀'));
    expect(updatedSc.statusExpiresAt, equals(expiryMs));
    expect(updatedSc.themeId, equals('garden'));
    expect(updatedSc.avatarBorderId, equals('neon_pulse'));
    expect(updatedSc.profileImageB64, equals('01020304'));

    // 4. Contact in chat list must be updated
    final updatedContact = appState.contacts.firstWhere((c) => c.keyHash == peerKey);
    expect(updatedContact.name, equals('Bob Renamed'));
    expect(updatedContact.shortNick, equals('BOBBY'));
    expect(updatedContact.themeId, equals('garden'));
    expect(updatedContact.avatarBorderId, equals('neon_pulse'));
    expect(updatedContact.profileImageB64, equals('01020304'));
  });

  test('database persistence saves and loads status_emoji and status_expires_at', () async {
    final expiryMs = DateTime.now().add(const Duration(hours: 12)).millisecondsSinceEpoch;
    final sc = SocialContact(
      id: 2,
      keyHash: 'test_db_peer_key',
      name: 'Charlie',
      shortNick: 'CHAR',
      sharedSecretSeed: 'seed456',
      myPubkey: 'pub1',
      peerPubkey: 'pub2',
      addedAt: DateTime.now().millisecondsSinceEpoch,
      status: 'Ready to pair',
      statusEmoji: '✨',
      statusExpiresAt: expiryMs,
    );

    await WiltkeyDatabase.instance.insertSocialContact(sc);
    final all = await WiltkeyDatabase.instance.getAllSocialContacts();
    final loaded = all.firstWhere((c) => c.keyHash == 'test_db_peer_key');

    expect(loaded.status, equals('Ready to pair'));
    expect(loaded.statusEmoji, equals('✨'));
    expect(loaded.statusExpiresAt, equals(expiryMs));
  });
}
