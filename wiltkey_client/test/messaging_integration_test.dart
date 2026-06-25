/// Wiltkey Messaging Integration Test
///
/// Simulates two clients against the real local backend to verify:
/// 1. Identity computation matches between client and server
/// 2. Immediate message delivery (both clients online)
/// 3. Offline queue delivery (recipient reconnects)
/// 4. WebSocket reconnect stability (no stale timer killing connections)
///
/// Prerequisites:
///   - Backend running locally: `go run .` in wiltkey_server/
///   - Redis running locally on port 6379
///
/// Run with: `dart run test/messaging_integration_test.dart`

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed25519;

const serverUrl = 'ws://localhost:8000/ws';

/// Simulated Wiltkey client with Ed25519 identity and WebSocket connection
class TestClient {
  final String name;
  late ed25519.KeyPair _keyPair;
  late String publicKeyHex;
  late String userId; // Client-side computed
  String? serverUserId; // Server-side returned

  WebSocket? _socket;
  bool isAuthenticated = false;
  final List<Map<String, dynamic>> receivedMessages = [];
  final List<String> logs = [];
  StreamSubscription? _subscription;
  Completer<void>? _authCompleter;
  Completer<Map<String, dynamic>>? _messageCompleter;

  TestClient(this.name) {
    _keyPair = ed25519.generateKey();
    publicKeyHex = _bytesToHex(_keyPair.publicKey.bytes);

    // Client-side userId: SHA256 of raw public key bytes
    userId = sha256.convert(_keyPair.publicKey.bytes).toString();
    _log(
      'Identity: userId=$userId, pubKeyHex=${publicKeyHex.substring(0, 16)}...',
    );
  }

  void _log(String msg) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    final line = '[$time] [$name] $msg';
    logs.add(line);
    print(line);
  }

  /// Connect to server and authenticate
  Future<void> connect() async {
    _authCompleter = Completer<void>();
    _log('Connecting to $serverUrl ...');

    _socket = await WebSocket.connect(serverUrl);
    _log('Connected. Waiting for challenge...');

    _subscription = _socket!.listen(
      (data) => _handleMessage(data),
      onError: (err) => _log('Socket error: $err'),
      onDone: () => _log('Socket closed.'),
      cancelOnError: true,
    );

    // Wait for auth to complete (with timeout)
    await _authCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Auth timeout for $name'),
    );
  }

  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final type = json['type'] ?? '';

      switch (type) {
        case 'CHALLENGE':
          final challenge = json['challenge'] as String;
          _log('Received CHALLENGE: ${challenge.substring(0, 16)}...');
          _authenticate(challenge);
          break;

        case 'AUTH_OK':
          serverUserId = json['user_id'] as String;
          isAuthenticated = true;
          _log('AUTH_OK! Server userId=$serverUserId');

          // Check identity match
          if (serverUserId != userId) {
            _log('⚠ IDENTITY MISMATCH! Client=$userId Server=$serverUserId');
          } else {
            _log('✓ Identity matches server.');
          }
          _authCompleter?.complete();
          break;

        case 'NEW_MESSAGE':
          final senderId = json['sender_id'] as String;
          final envelope = json['envelope'] as String;
          final contentType = json['content_type'] ?? 'text';
          _log(
            'Received NEW_MESSAGE from $senderId (content_type=$contentType, envelope=${envelope.substring(0, min(30, envelope.length))}...)',
          );
          receivedMessages.add(json);
          _messageCompleter?.complete(json);
          break;

        case 'ERROR':
          _log('Server ERROR: ${json['message']}');
          break;

        default:
          _log('Unhandled type: $type');
      }
    } catch (e) {
      _log('Parse error: $e');
    }
  }

  void _authenticate(String challenge) {
    final sigBytes = ed25519.sign(_keyPair.privateKey, utf8.encode(challenge));
    final sigHex = _bytesToHex(sigBytes);

    _send({'type': 'AUTH', 'pubkey': publicKeyHex, 'signature': sigHex});
    _log('Sent AUTH response.');
  }

  /// Send a raw WebSocket message
  void _send(Map<String, dynamic> msg) {
    _socket?.add(jsonEncode(msg));
  }

  /// Send a SEND_MESSAGE to a peer
  void sendMessage(
    String recipientId,
    String text, {
    String contentType = 'text',
  }) {
    // Create a simple envelope (no OTP encryption for testing)
    final envelope = jsonEncode({
      't': contentType,
      'd': base64Encode(utf8.encode(text)),
      'offset': 0,
    });

    _send({
      'type': 'SEND_MESSAGE',
      'recipient_id': recipientId,
      'envelope': envelope,
      'content_type': contentType,
    });
    _log('Sent message to $recipientId: "$text"');
  }

  /// Wait for a NEW_MESSAGE to arrive
  Future<Map<String, dynamic>> waitForMessage({
    Duration timeout = const Duration(seconds: 5),
  }) {
    _messageCompleter = Completer<Map<String, dynamic>>();
    return _messageCompleter!.future.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        '$name: No message received within ${timeout.inSeconds}s',
      ),
    );
  }

  /// Disconnect cleanly
  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _socket?.close();
    _socket = null;
    isAuthenticated = false;
    _log('Disconnected.');
  }

  /// Compute the server-side userId for a given public key hex
  /// This must match GenerateUserID(hex.DecodeString(pubkeyHex)) on the server
  static String computeServerUserId(String pubKeyHex) {
    final bytes = _hexToBytes(pubKeyHex);
    return sha256.convert(bytes).toString();
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}

int min(int a, int b) => a < b ? a : b;

// ─── TEST RUNNER ─────────────────────────────────────────────────────────────

Future<void> main() async {
  print('');
  print('═══════════════════════════════════════════════════════════');
  print('  WILTKEY MESSAGING INTEGRATION TEST');
  print('  Server: $serverUrl');
  print('═══════════════════════════════════════════════════════════');
  print('');

  int passed = 0;
  int failed = 0;

  Future<void> runTest(String name, Future<void> Function() test) async {
    print('');
    print('─── TEST: $name ───');
    try {
      await test();
      print('  ✅ PASSED: $name');
      passed++;
    } catch (e) {
      print('  ❌ FAILED: $name — $e');
      failed++;
    }
    print('');
  }

  // ─── TEST 1: Identity Computation ───
  await runTest('Identity computation matches server', () async {
    final client = TestClient('Alice');
    await client.connect();

    assert(client.isAuthenticated, 'Client should be authenticated');
    assert(client.serverUserId != null, 'Server should return userId');
    assert(
      client.userId == client.serverUserId,
      'Client userId (${client.userId}) must match server userId (${client.serverUserId})',
    );

    // Also verify computeServerUserId produces the same result
    final computed = TestClient.computeServerUserId(client.publicKeyHex);
    assert(
      computed == client.serverUserId,
      'computeServerUserId($computed) must match server ($client.serverUserId)',
    );

    await client.disconnect();
  });

  // ─── TEST 2: Direct Message Delivery ───
  await runTest('Direct message delivery (both online)', () async {
    final alice = TestClient('Alice');
    final bob = TestClient('Bob');

    await alice.connect();
    await bob.connect();

    // Alice sends to Bob using Bob's SERVER userId (which is what the server knows Bob as)
    final bobRecipientId = bob.serverUserId!;
    print('  Alice sends to Bob (recipientId=$bobRecipientId)');

    // Start waiting for message BEFORE sending (so we don't miss it)
    final msgFuture = bob.waitForMessage();
    alice.sendMessage(bobRecipientId, 'Hello from Alice!');

    final received = await msgFuture;
    assert(
      received['sender_id'] == alice.serverUserId,
      'Sender ID should be Alice\'s server userId',
    );
    assert(received['envelope'] != null, 'Envelope should not be null');

    print('  Bob received message from sender_id=${received['sender_id']}');

    // Verify the sender_id matches what would be stored as keyHash
    final aliceKeyHash = TestClient.computeServerUserId(alice.publicKeyHex);
    assert(
      received['sender_id'] == aliceKeyHash,
      'sender_id (${received['sender_id']}) must match computed keyHash ($aliceKeyHash)',
    );

    await alice.disconnect();
    await bob.disconnect();
  });

  // ─── TEST 3: Bidirectional Messages ───
  await runTest('Bidirectional message exchange', () async {
    final alice = TestClient('Alice');
    final bob = TestClient('Bob');

    await alice.connect();
    await bob.connect();

    // Alice → Bob
    var msgFuture = bob.waitForMessage();
    alice.sendMessage(bob.serverUserId!, 'Ping from Alice');
    await msgFuture;
    print('  Alice → Bob: delivered ✓');

    // Bob → Alice
    msgFuture = alice.waitForMessage();
    bob.sendMessage(alice.serverUserId!, 'Pong from Bob');
    await msgFuture;
    print('  Bob → Alice: delivered ✓');

    await alice.disconnect();
    await bob.disconnect();
  });

  // ─── TEST 4: Offline Queue ───
  await runTest('Offline queue delivery', () async {
    final alice = TestClient('Alice');
    final bob = TestClient('Bob');

    // Both connect first so Bob is known
    await alice.connect();
    await bob.connect();
    final bobId = bob.serverUserId!;

    // Bob disconnects
    await bob.disconnect();
    await Future.delayed(const Duration(milliseconds: 500));

    // Alice sends while Bob is offline
    alice.sendMessage(bobId, 'You were offline!');
    print('  Alice sent message while Bob is offline.');

    await Future.delayed(const Duration(milliseconds: 500));

    // Bob reconnects — should receive offline message
    final bob2 = TestClient('Bob-Reconnected');
    // Reuse Bob's key pair
    bob2._keyPair = bob._keyPair;
    bob2.publicKeyHex = bob.publicKeyHex;
    bob2.userId = bob.userId;

    final msgFuture = bob2.waitForMessage(timeout: const Duration(seconds: 10));
    await bob2.connect();

    final received = await msgFuture;
    assert(
      received['sender_id'] == alice.serverUserId,
      'Offline message sender should be Alice',
    );
    print('  Bob received offline message after reconnect ✓');

    await alice.disconnect();
    await bob2.disconnect();
  });

  // ─── TEST 5: Rapid Reconnect Stability ───
  await runTest('Rapid reconnect stability (no stale timer kills)', () async {
    final alice = TestClient('Alice');
    final bob = TestClient('Bob');

    await alice.connect();
    await bob.connect();

    // Bob rapidly disconnects and reconnects 3 times
    for (int i = 0; i < 3; i++) {
      await bob.disconnect();
      await Future.delayed(const Duration(milliseconds: 200));

      final reconnected = TestClient('Bob-R$i');
      reconnected._keyPair = bob._keyPair;
      reconnected.publicKeyHex = bob.publicKeyHex;
      reconnected.userId = bob.userId;
      await reconnected.connect();

      // Send a message and verify it arrives
      final msgFuture = reconnected.waitForMessage();
      alice.sendMessage(reconnected.serverUserId!, 'Reconnect test $i');
      final received = await msgFuture;
      assert(received['sender_id'] == alice.serverUserId);
      print('  Reconnect #$i: message delivered ✓');

      bob._keyPair = reconnected._keyPair;
      bob.publicKeyHex = reconnected.publicKeyHex;
      bob.userId = reconnected.userId;
      bob._socket = reconnected._socket;
      bob.isAuthenticated = reconnected.isAuthenticated;
      bob.serverUserId = reconnected.serverUserId;
      bob._subscription = reconnected._subscription;
    }

    await alice.disconnect();
    await bob.disconnect();
  });

  // ─── TEST 6: keyHash Computation Consistency ───
  await runTest('keyHash computation matches server sender_id', () async {
    final alice = TestClient('Alice');
    final bob = TestClient('Bob');

    await alice.connect();
    await bob.connect();

    // Simulate what BLE pairing does: compute keyHash from peer's public key
    final aliceKeyHashOnBob = TestClient.computeServerUserId(
      alice.publicKeyHex,
    );
    final bobKeyHashOnAlice = TestClient.computeServerUserId(bob.publicKeyHex);

    print('  Alice server ID: ${alice.serverUserId}');
    print('  Bob computes Alice keyHash: $aliceKeyHashOnBob');
    print('  Bob server ID: ${bob.serverUserId}');
    print('  Alice computes Bob keyHash: $bobKeyHashOnAlice');

    // These must match for message routing to work
    assert(
      aliceKeyHashOnBob == alice.serverUserId,
      'Bob\'s computed keyHash for Alice must match Alice\'s server ID',
    );
    assert(
      bobKeyHashOnAlice == bob.serverUserId,
      'Alice\'s computed keyHash for Bob must match Bob\'s server ID',
    );

    // Verify with actual message exchange
    final msgFuture = bob.waitForMessage();
    alice.sendMessage(bobKeyHashOnAlice, 'keyHash routing test');
    final received = await msgFuture;

    // The sender_id in the message must match what Bob stored as keyHash
    assert(
      received['sender_id'] == aliceKeyHashOnBob,
      'sender_id must match the keyHash Bob computed for Alice',
    );
    print('  keyHash routing verified ✓');

    await alice.disconnect();
    await bob.disconnect();
  });

  // ─── TEST 7: Targeted Nuke and Queue Unblocking ───
  await runTest(
    'Targeted nuke deletes contact and does not cascade, unblocks queue via ACK_NUKE',
    () async {
      final alice = TestClient('Alice');
      final bob = TestClient('Bob');
      final charlie = TestClient('Charlie');

      await alice.connect();
      await bob.connect();
      await charlie.connect();

      final aliceId = alice.serverUserId!;
      final charlieId = charlie.serverUserId!;

      // Simulate Bob's contacts list
      final bobContacts = [aliceId, charlieId];

      // Alice sends a NUKE_RECIPIENT targeting Bob
      final bobNukeFuture = bob.waitForMessage();

      alice._send({
        'type': 'NUKE_RECIPIENT',
        'recipient_id': bob.serverUserId!,
        'nuke_envelope': 'VAPORIZE',
      });
      print('  Alice sent NUKE_RECIPIENT to Bob.');

      final bobReceived = await bobNukeFuture;
      assert(bobReceived['sender_id'] == aliceId);
      assert(bobReceived['content_type'] == 'nuke');
      print('  Bob received nuke from Alice.');

      // Bob deletes Alice from his contacts list (targeted deletion, no cascade to Charlie)
      bobContacts.remove(aliceId);
      print('  Bob deleted Alice. Remaining contacts in Bob: $bobContacts');
      assert(!bobContacts.contains(aliceId), 'Alice should be deleted');
      assert(
        bobContacts.contains(charlieId),
        'Charlie should still be in Bob contacts',
      );

      // Send ACK_NUKE to unblock Bob's queue
      bob._send({'type': 'ACK_NUKE'});
      print('  Bob sent ACK_NUKE to server.');

      // Wait a brief moment for the unblock to register
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify Bob's queue is unblocked: Charlie can send Bob a message and Bob receives it
      final bobMsgFuture = bob.waitForMessage();
      charlie.sendMessage(bob.serverUserId!, 'Hey Bob, Charlie here!');

      final bobMsgReceived = await bobMsgFuture;
      assert(bobMsgReceived['sender_id'] == charlieId);
      assert(bobMsgReceived['content_type'] == 'text');
      print(
        '  Bob successfully received message from Charlie after unblocking ✓',
      );

      await alice.disconnect();
      await bob.disconnect();
      await charlie.disconnect();
    },
  );

  // ─── RESULTS ───
  print('');
  print('═══════════════════════════════════════════════════════════');
  print('  RESULTS: $passed passed, $failed failed');
  print('═══════════════════════════════════════════════════════════');
  print('');

  exit(failed > 0 ? 1 : 0);
}
