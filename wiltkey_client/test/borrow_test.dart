// 1-on-1 BYTE-BORROWING (disjoint multi-range keystream) harness.
//
// Verifies the borrow_request / borrow_grant flow that replaced the old
// boundary-move resplit. The key win: it works EVEN AFTER BOTH SIDES HAVE SENT
// (the case the old resplit rejected to avoid OTP reuse). The donor lends the
// top half of its own UNUSED lane (pristine bytes); the requester records that
// as a disjoint extra send range and can encrypt into it.
//
// Drives the REAL dispatch path (WebSocketClient.onMessageReceived ->
// _dispatchIncoming -> handlers); peers are simulated by crafting wire frames,
// outbound frames captured via onMessageSent. Role (initiator vs not) is forced
// by picking peer hashes with 63 leading 'f'/'0' chars, and asserted via the
// enrolled offsets so a freak userId ordering fails loudly.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiltkey_client/core/state.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/crypto/otp_service.dart';
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

  const int buffer = 2000; // boundary at 1000
  const String seed =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  // Distinct fresh seed per enrollment: a recharge under the SAME seed now
  // throws (replay guard), and tests re-enroll the same peers across cases.
  int _enrollCounter = 0;
  String nextFreshSeed() =>
      (_enrollCounter++).toRadixString(16).padLeft(2, '0') * 32;

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
    final fresh = nextFreshSeed();
    await appState.addOrRechargeContact(
      'Peer',
      appState.localDevRelayUrl,
      buffer,
      keyHash,
      seed,
      freshSeedHex: fresh,
    );
    return appState.contacts.firstWhere((c) => c.keyHash == keyHash);
  }

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
  setUpAll(() async {
    await deleteStalePads();
    await startFakeRelay();
    appState = AppState();
    appState.useLocalDevRelay = true;
    appState.localDevRelayUrl = 'http://127.0.0.1:${server.port}';

    if (appState.isLocked || appState.isOnboardingRequired) {
      await appState.setupPinAndInitialize(
        pin: '1234',
        username: 'AliceUser',
        codename: 'ALICE',
        profileImage: 'pic_hex',
      );
    }
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
    await deleteStalePads();
    appState.stopConnectionWatchdog();
    WebSocketClient().disconnect();
    await server.close(force: true);
  });

  tearDown(() => WebSocketClient().onMessageSent = null);

  test('trigger: a send on an empty lane requests a borrow', () async {
    final keyHash = 'f' * 63 + '1';
    final contact = await enroll(keyHash);
    expect(
      contact.outgoingOffset,
      equals(0),
      reason: 'local should be initiator',
    );

    // Primary lane fully consumed, no borrowed ranges.
    contact.outgoingOffset = contact.outgoingMaxOffset; // 1000
    contact.remainingBufferBytes = 0;
    appState.activeContact = contact;

    final sent = <Map<String, dynamic>>[];
    WebSocketClient().onMessageSent = (m) => sent.add(m);

    final err = await appState.sendMessage('x');
    expect(err, isNotNull, reason: 'send should defer while it borrows');
    await Future.delayed(const Duration(milliseconds: 150));

    expect(
      sent.any(
        (m) =>
            m['content_type'] == 'borrow_request' &&
            m['recipient_id'] == keyHash,
      ),
      isTrue,
    );
  });

  test(
    'donor lends the top half of its UNUSED lane even after it has sent',
    () async {
      final keyHash = '0' * 63 + '1'; // < userId → local is non-initiator/donor
      final contact = await enroll(keyHash);
      expect(
        contact.outgoingOffset,
        equals(1000),
        reason: 'local should be non-initiator',
      );

      // Donor has ALREADY sent 200 bytes (used [1000,1200)). This is exactly the
      // case the old resplit rejected. Unused tail = [1200,2000) = 800B.
      contact.outgoingOffset = 1200;

      final sent = <Map<String, dynamic>>[];
      WebSocketClient().onMessageSent = (m) => sent.add(m);

      WebSocketClient().onMessageReceived!(
        keyHash,
        jsonEncode({'borrow': true}),
        'borrow_request',
      );
      await Future.delayed(const Duration(milliseconds: 150));

      // Donates half of 800 = 400: keeps [1200,1600), lends [1600,2000).
      expect(
        contact.outgoingMaxOffset,
        equals(1600),
        reason: 'ceiling drops by the donated amount',
      );
      final grant = sent.firstWhere(
        (m) => m['content_type'] == 'borrow_grant',
        orElse: () => {},
      );
      expect(grant, isNotEmpty);
      final env =
          jsonDecode(grant['envelope'] as String) as Map<String, dynamic>;
      expect(env['start'], equals(1600));
      expect(env['end'], equals(2000));
      // Donated range starts ABOVE the donor's used region — no key reuse.
      expect(env['start'] as int, greaterThanOrEqualTo(contact.outgoingOffset));
    },
  );

  test('requester records a donated range and then encrypts INTO it', () async {
    final keyHash = 'f' * 63 + '2'; // initiator/requester
    final contact = await enroll(keyHash);
    expect(contact.outgoingOffset, equals(0));

    // Primary lane is exhausted.
    contact.outgoingOffset = contact.outgoingMaxOffset; // 1000
    contact.remainingBufferBytes = 0;

    // Peer grants us its tail [1500,2000).
    WebSocketClient().onMessageReceived!(
      keyHash,
      jsonEncode({'start': 1500, 'end': 2000}),
      'borrow_grant',
    );
    await Future.delayed(const Duration(milliseconds: 150));

    expect(
      contact.additionalSlots,
      equals([1500, 1500, 2000]),
      reason: 'stored as [start,ptr,end]',
    );
    expect(contact.remainingBufferBytes, equals(500));
    expect(contact.isWilted, isFalse);

    // Now a send must use the borrowed range (primary is full).
    appState.activeContact = contact;
    final sent = <Map<String, dynamic>>[];
    WebSocketClient().onMessageSent = (m) => sent.add(m);

    final err = await appState.sendMessage('hello');
    expect(err, isNull, reason: 'the borrowed range makes the send succeed');
    await Future.delayed(const Duration(milliseconds: 150));

    final frame = sent.firstWhere(
      (m) => m['content_type'] == 'text',
      orElse: () => {},
    );
    expect(frame, isNotEmpty);
    final offset = jsonDecode(frame['envelope'] as String)['offset'] as int;
    expect(
      offset,
      equals(1500),
      reason: 'encrypted at the start of the borrowed range',
    );
    // Pointer advanced by len('hello') = 5.
    expect(contact.additionalSlots[1], equals(1505));
  });

  test(
    'a message arriving in a borrowed range decrypts without a false resync',
    () async {
      final keyHash =
          '0' * 63 + '3'; // non-initiator donor; incoming primary = [0,1000)
      final contact = await enroll(keyHash);
      expect(contact.incomingMaxOffset, equals(1000));
      appState.activeContact = contact;

      final sent = <Map<String, dynamic>>[];
      WebSocketClient().onMessageSent = (m) => sent.add(m);

      // The peer sends at offset 1500 (in the tail we lent it). Same shared pad,
      // so it decrypts by absolute offset.
      const text = 'borrowed hello';
      final cipher = await WiltkeyOtpService.xorWithKeystream(
        keyHash,
        utf8.encode(text),
        1500,
      );
      final envelope = jsonEncode({
        't': 'text',
        'd': base64Encode(cipher),
        'offset': 1500,
        'id': 'b1',
      });
      WebSocketClient().onMessageReceived!(keyHash, envelope, 'text');
      await Future.delayed(const Duration(milliseconds: 200));

      final msgs = appState.messages[contact.id] ?? [];
      final got = msgs.firstWhere(
        (m) => m.id == 'b1',
        orElse: () => throw 'message not appended',
      );
      expect(
        got.decryptedText,
        equals(text),
        reason: 'decrypts by absolute offset',
      );

      // Out-of-primary-lane offset must NOT drive gap detection, and must not
      // corrupt the primary incoming pointer.
      //
      // Note we can't assert "no resync at all" any more: the primary lane
      // [0,1000) is genuinely still empty here, so maybeAutoReconcileOnPeerMessage
      // legitimately pulls that gap on the peer's arrival. What must never happen
      // is a resync reaching into the range we LENT — that would mean the borrowed
      // write was mistaken for a hole in the peer's own lane.
      final resyncs = sent.where(
        (m) => m['content_type'] == 'chat_resync_request',
      );
      for (final r in resyncs) {
        final env = jsonDecode(r['envelope'] as String) as Map<String, dynamic>;
        expect(
          env['end_offset'] as int,
          lessThanOrEqualTo(1000),
          reason: 'resync must stay inside the primary incoming lane',
        );
      }
      expect(contact.incomingOffset, lessThanOrEqualTo(1000));
    },
  );

  // Regression: the same "is this offset in the peer's primary lane?" guard has
  // to hold for an INITIATOR lender too. An initiator's incoming lane is the
  // UPPER half, so a range it lends out of its own (lower) outgoing lane sits
  // BELOW incomingMaxOffset — a top-bound-only check waved it straight through
  // and silently drained the displayed peer budget on every borrowed write.
  test('a borrowed-range arrival below the incoming lane is not counted', () async {
    final keyHash = 'f' * 63 + '4'; // > userId → local is initiator/lender
    final contact = await enroll(keyHash);
    expect(
      contact.outgoingOffset,
      equals(0),
      reason: 'local should be initiator (outgoing = lower half)',
    );
    expect(contact.incomingMaxOffset, equals(2000));
    appState.activeContact = contact;

    // We lend the peer the top half of our own unused outgoing lane: [500,1000).
    contact.outgoingMaxOffset = 500;
    final peerBudgetBefore = contact.peerRemainingBufferBytes;
    final incomingBefore = contact.incomingOffset;

    // The peer writes into the range we lent it (offset 600 — inside OUR lane,
    // and below our incomingMaxOffset of 2000).
    const text = 'lent bytes';
    final cipher = await WiltkeyOtpService.xorWithKeystream(
      keyHash,
      utf8.encode(text),
      600,
    );
    WebSocketClient().onMessageReceived!(
      keyHash,
      jsonEncode({
        't': 'text',
        'd': base64Encode(cipher),
        'offset': 600,
        'id': 'b2',
      }),
      'text',
    );
    await Future.delayed(const Duration(milliseconds: 200));

    final got = (appState.messages[contact.id] ?? []).firstWhere(
      (m) => m.id == 'b2',
      orElse: () => throw 'message not appended',
    );
    expect(got.decryptedText, equals(text), reason: 'decrypts by absolute offset');

    // The write consumed OUR lent bytes, not the peer's lane — their budget and
    // our incoming pointer must both be untouched.
    expect(contact.peerRemainingBufferBytes, equals(peerBudgetBefore));
    expect(contact.incomingOffset, equals(incomingBefore));
  });
}
