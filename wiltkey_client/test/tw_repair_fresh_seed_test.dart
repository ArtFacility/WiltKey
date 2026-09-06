import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiltkey_client/core/chat_metadata.dart';
import 'package:wiltkey_client/core/crypto/otp_service.dart';
import 'package:wiltkey_client/core/db/wiltkey_db.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/network/qr_pair_controller.dart';
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  PathProviderPlatform.instance = MockPathProviderPlatform();

  Future<void> deleteStalePads() async {
    final dir = Directory('.');
    await for (final e in dir.list()) {
      if (e is File &&
          e.uri.pathSegments.last.startsWith('keystream_') &&
          e.uri.pathSegments.last.endsWith('.pad')) {
        try {
          await e.delete();
        } catch (_) {}
      }
    }
  }

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

  setUp(() async {
    await deleteStalePads();
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
    await deleteStalePads();
    final dbFile = File('wiltkey.db');
    if (await dbFile.exists()) {
      try {
        await dbFile.delete();
      } catch (_) {}
    }
  });

  // Deterministic lane bases mirror state_lifecycle's userId-compare split.
  (int, int) laneBases(String peerHash) {
    final isInit = appState.userId.compareTo(peerHash) < 0;
    final stride = WiltkeyOtpService.kWiltLaneStride;
    return (isInit ? 0 : stride, isInit ? stride : 0);
  }

  String metaKeyFor(String seed) =>
      sha256.convert(utf8.encode('$seed:meta')).toString();

  Future<Contact> createTwContact(
    String peerHash, {
    required String freshSeed,
  }) async {
    await appState.addOrRechargeTimeWiltContact(
      'Peer',
      'https://relay.example.org',
      peerHash,
      'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
      DateTime.now().toUtc().add(const Duration(days: 7)),
      freshSeedHex: freshSeed,
    );
    return appState.contacts.firstWhere((c) => c.keyHash == peerHash);
  }

  test('new Time Wilt contact is keyed on the fresh seed, not the derivation',
      () async {
    const peer = 'aaaa0000000000000000000000000000000000000000000000000000000000aa';
    const fresh = 'bbbb1111111111111111111111111111111111111111111111111111111111bb';
    final contact = await createTwContact(peer, freshSeed: fresh);

    expect(contact.streamSeedHex, equals(fresh));
    expect(contact.isTimeWilt, isTrue);
    expect(contact.maxBufferBytes, equals(0));
    expect(await ChatMetaStore.keyFor(peer), equals(metaKeyFor(fresh)));
  });

  test('new contact WITHOUT a fresh seed is refused (no public fallback)',
      () async {
    const peer = 'cccc2222222222222222222222222222222222222222222222222222222222cc';
    // The deterministic pubkey derivation is publicly recomputable by the
    // relay (it sees both pubkeys in AUTH) — creating a contact from it must
    // fail closed, not fall back.
    await expectLater(
      appState.addOrRechargeTimeWiltContact(
        'Peer',
        'https://relay.example.org',
        peer,
        'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
        DateTime.now().toUtc().add(const Duration(days: 7)),
      ),
      throwsA(isA<Exception>()),
    );
    expect(
      appState.contacts.indexWhere((c) => c.keyHash == peer),
      equals(-1),
      reason: 'nothing may be created from public key material',
    );
  });

  test('malformed fresh seed is refused (fail-closed)', () async {
    const peer = 'cccc3333333333333333333333333333333333333333333333333333333333cc';
    await expectLater(
      appState.addOrRechargeTimeWiltContact(
        'Peer',
        'https://relay.example.org',
        peer,
        'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
        DateTime.now().toUtc().add(const Duration(days: 7)),
        freshSeedHex: 'not-hex-or-too-short',
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('re-pair with the SAME seed is refused and offsets stay advanced',
      () async {
    const peer = 'dddd3333333333333333333333333333333333333333333333333333333333dd';
    const fresh = 'eeee4444444444444444444444444444444444444444444444444444444444ee';
    final contact = await createTwContact(peer, freshSeed: fresh);
    final (outBase, _) = laneBases(peer);
    final burned = outBase + 4096;
    contact.outgoingOffset = burned;
    contact.incomingOffset = burned;
    await WiltkeyDatabase.instance.upsertContact(contact);

    await expectLater(
      appState.addOrRechargeTimeWiltContact(
        'Peer',
        'https://relay.example.org',
        peer,
        'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
        DateTime.now().toUtc().add(const Duration(days: 7)),
        freshSeedHex: fresh,
      ),
      throwsA(isA<Exception>()),
    );

    final after = appState.contacts.firstWhere((c) => c.keyHash == peer);
    expect(after.streamSeedHex, equals(fresh));
    expect(after.outgoingOffset, equals(burned));
    expect(after.incomingOffset, equals(burned));
    expect(await ChatMetaStore.keyFor(peer), equals(metaKeyFor(fresh)));
  });

  test('re-pair with a NEW seed swaps material and resets offsets safely',
      () async {
    const peer = 'ffff5555555555555555555555555555555555555555555555555555555555ff';
    const oldSeed = '1111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa11';
    const newSeed = '2222bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb22';
    final contact = await createTwContact(peer, freshSeed: oldSeed);
    final (outBase, inBase) = laneBases(peer);
    contact.outgoingOffset = outBase + 12345;
    contact.incomingOffset = inBase + 6789;
    await WiltkeyDatabase.instance.upsertContact(contact);

    await appState.addOrRechargeTimeWiltContact(
      'Peer',
      'https://relay.example.org',
      peer,
      'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
      DateTime.now().toUtc().add(const Duration(days: 7)),
      freshSeedHex: newSeed,
    );

    final after = appState.contacts.firstWhere((c) => c.keyHash == peer);
    expect(after.streamSeedHex, equals(newSeed));
    // Offsets reset — SAFE because the keystream material itself changed.
    expect(after.outgoingOffset, equals(outBase));
    expect(after.incomingOffset, equals(inBase));
    expect(await ChatMetaStore.keyFor(peer), equals(metaKeyFor(newSeed)));
  });

  test('Time Wilt pairing is refused over an existing OTP-pad contact',
      () async {
    const peer = 'aaaa6666666666666666666666666666666666666666666666666666666aa';
    final padContact = Contact(
      id: 'pad_${peer.substring(0, 8)}',
      name: 'Pad Peer',
      keyHash: peer,
      relayUrl: 'https://relay.example.org',
      isPrivateNode: false,
      maxBufferBytes: 1024 * 1024,
      remainingBufferBytes: 1024 * 1024,
      peerRemainingBufferBytes: 1024 * 1024,
      lastActivity: DateTime.now(),
    );
    appState.contacts.add(padContact);
    await WiltkeyDatabase.instance.upsertContact(padContact);

    await expectLater(
      appState.addOrRechargeTimeWiltContact(
        'Peer',
        'https://relay.example.org',
        peer,
        'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
        DateTime.now().toUtc().add(const Duration(days: 7)),
        freshSeedHex: '3333cccccccccccccccccccccccccccccccccccccccccccccccccccccccc33',
      ),
      throwsA(isA<Exception>()),
    );

    // The pad contact must be untouched.
    final after = appState.contacts.firstWhere((c) => c.keyHash == peer);
    expect(after.maxBufferBytes, equals(1024 * 1024));
    expect(after.streamSeedHex, isNull);
  });

  test('pad recharge without a fresh seed is refused; with one it succeeds',
      () async {
    const peer = 'bbbb7777777777777777777777777777777777777777777777777777777777bb';
    const fresh = '4444dddddddddddddddddddddddddddddddddddddddddddddddddddddddddd44';
    const fresh2 = '5555eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee55';

    // Brand-new pad contact, keyed on the fresh seed.
    await appState.addOrRechargeContact(
      'Pad Peer',
      'https://relay.example.org',
      1024 * 1024,
      peer,
      'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
      freshSeedHex: fresh,
    );
    final padFile = File('keystream_$peer.pad');
    expect(await padFile.exists(), isTrue);
    expect(await ChatMetaStore.keyFor(peer), equals(metaKeyFor(fresh)));

    // Recharge WITHOUT fresh material — must be refused, pad file untouched.
    await expectLater(
      appState.addOrRechargeContact(
        'Pad Peer',
        'https://relay.example.org',
        1024 * 1024,
        peer,
        'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
      ),
      throwsA(isA<Exception>()),
    );

    // Recharge with the SAME seed REPLAYED — must be refused (would
    // regenerate the identical pad and rewind offsets into burned keystream).
    await expectLater(
      appState.addOrRechargeContact(
        'Pad Peer',
        'https://relay.example.org',
        1024 * 1024,
        peer,
        'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
        freshSeedHex: fresh,
      ),
      throwsA(isA<Exception>()),
    );
    expect(await WiltkeyOtpService.padMatchesSeed(peer, fresh), isTrue,
        reason: 'pad must be untouched after both refusals');

    // Recharge WITH fresh material — pad regenerated from the new seed,
    // offsets reset (safe: the keystream bytes themselves changed). Pad
    // contacts use BYTE lane bases (0 / buffer/2), not the TW stride.
    final contact =
        appState.contacts.firstWhere((c) => c.keyHash == peer);
    const padBuffer = 1024 * 1024;
    final padOutBase = appState.userId.compareTo(peer) < 0 ? 0 : padBuffer ~/ 2;
    contact.outgoingOffset = padOutBase + 999;
    await WiltkeyDatabase.instance.upsertContact(contact);

    await appState.addOrRechargeContact(
      'Pad Peer',
      'https://relay.example.org',
      padBuffer,
      peer,
      'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
      freshSeedHex: fresh2,
    );

    final after = appState.contacts.firstWhere((c) => c.keyHash == peer);
    expect(after.outgoingOffset, equals(padOutBase));
    expect(await ChatMetaStore.keyFor(peer), equals(metaKeyFor(fresh2)));
  });

  test('QR pair seed derivation is role-free and bound to both nonces',
      () async {
    const nonceA = 'aaaa1111111111111111111111111111111111111111111111111111111111';
    const nonceB = 'bbbb2222222222222222222222222222222222222222222222222222222222';
    const pubA = 'cccc3333333333333333333333333333333333333333333333333333333333';
    const pubB = 'dddd4444444444444444444444444444444444444444444444444444444444';

    final ab = deriveQrPairSeedHex(
        nonceA: nonceA, nonceB: nonceB, pubA: pubA, pubB: pubB);
    final ba = deriveQrPairSeedHex(
        nonceA: nonceB, nonceB: nonceA, pubA: pubB, pubB: pubA);
    expect(ab, equals(ba), reason: 'both devices must derive the same seed');

    // Secret vs the old public derivation: knowing only the pubkeys must NOT
    // yield the QR pair seed (the relay can recompute the deterministic one).
    final pubs = [pubA, pubB]..sort();
    final publicDerivation =
        sha256.convert(utf8.encode(pubs[0] + pubs[1])).toString();
    expect(ab, isNot(equals(publicDerivation)));

    // Bound to the nonces: swapping one nonce changes the seed.
    final other = deriveQrPairSeedHex(
      nonceA: 'eeee5555555555555555555555555555555555555555555555555555555555ee',
      nonceB: nonceB,
      pubA: pubA,
      pubB: pubB,
    );
    expect(other, isNot(equals(ab)));
  });
}
