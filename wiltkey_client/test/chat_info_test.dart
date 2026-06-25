// 1-on-1 chat_info_update (profile + permission sync) harness.
//
// Verifies the AES metadata channel that mirrors the group group_info_update:
// the key is the one-way SHA256(seed + ":meta") provisioned at enrol, profiles
// merge in (never overwriting good values with blanks), and outbound updates are
// decryptable by the peer. Drives the real dispatch path.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiltkey_client/core/state.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/persistence.dart';
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
  const String seed =
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
  String metaKey() => sha256.convert(utf8.encode('$seed:meta')).toString();

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
          } catch (_) {}
        });
      } else {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    });
  }

  Future<Contact> enroll(String keyHash) async {
    await appState.addOrRechargeContact(
      'OldName',
      appState.localDevRelayUrl,
      100000,
      keyHash,
      seed,
    );
    return appState.contacts.firstWhere((c) => c.keyHash == keyHash);
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
    'receive: applies peer name/nick/avatar and the image permission',
    () async {
      final keyHash = 'c' * 64;
      final contact = await enroll(keyHash);
      expect(contact.name, equals('OldName'));

      final payload = jsonEncode({
        'name': 'Bob Updated',
        'short_nick': 'BOBBY',
        'profile_image': 'bob_new_avatar',
        'images_allowed': false,
        'v': 1,
      });
      final enc = WiltkeyPersistence().encryptString(payload, metaKey());
      WebSocketClient().onMessageReceived!(
        keyHash,
        jsonEncode({'d': enc}),
        'chat_info_update',
      );
      await Future.delayed(const Duration(milliseconds: 200));

      final c = appState.contacts.firstWhere((x) => x.keyHash == keyHash);
      expect(c.name, equals('Bob Updated'));
      expect(c.shortNick, equals('BOBBY'));
      expect(c.profileImageB64, equals('bob_new_avatar'));
      expect(c.imagesAllowed, isFalse);
    },
  );

  test('receive: blank fields do NOT clobber existing good values', () async {
    final keyHash = 'd' * 64;
    await enroll(keyHash);

    // First a good update, then one with blank name/avatar.
    final good = WiltkeyPersistence().encryptString(
      jsonEncode({'name': 'Real Name', 'profile_image': 'real_pic', 'v': 1}),
      metaKey(),
    );
    WebSocketClient().onMessageReceived!(
      keyHash,
      jsonEncode({'d': good}),
      'chat_info_update',
    );
    await Future.delayed(const Duration(milliseconds: 150));

    final blank = WiltkeyPersistence().encryptString(
      jsonEncode({
        'name': '',
        'profile_image': '',
        'images_allowed': true,
        'v': 1,
      }),
      metaKey(),
    );
    WebSocketClient().onMessageReceived!(
      keyHash,
      jsonEncode({'d': blank}),
      'chat_info_update',
    );
    await Future.delayed(const Duration(milliseconds: 150));

    final c = appState.contacts.firstWhere((x) => x.keyHash == keyHash);
    expect(
      c.name,
      equals('Real Name'),
      reason: 'blank name must not overwrite',
    );
    expect(
      c.profileImageB64,
      equals('real_pic'),
      reason: 'blank avatar must not overwrite',
    );
    expect(
      c.imagesAllowed,
      isTrue,
      reason: 'non-null permission still applies',
    );
  });

  test(
    'send: emits a frame the peer can decrypt with the shared metadata key',
    () async {
      final keyHash = 'e' * 64;
      final contact = await enroll(keyHash);

      final sent = <Map<String, dynamic>>[];
      WebSocketClient().onMessageSent = (m) => sent.add(m);

      await appState.sendChatInfoUpdate(contact);
      await Future.delayed(const Duration(milliseconds: 150));

      final frame = sent.firstWhere(
        (m) =>
            m['content_type'] == 'chat_info_update' &&
            m['recipient_id'] == keyHash,
        orElse: () => {},
      );
      expect(frame, isNotEmpty);
      final d = jsonDecode(frame['envelope'] as String)['d'] as String;
      final payload =
          jsonDecode(WiltkeyPersistence().decryptString(d, metaKey()))
              as Map<String, dynamic>;
      expect(payload['profile_image'], equals('alice_pic_hex'));
      expect((payload['name'] as String), contains('AliceUser'));
    },
  );
}
