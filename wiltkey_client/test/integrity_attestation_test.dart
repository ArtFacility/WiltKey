import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/network/integrity_attestation_manager.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed25519;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClientBadgeType Model Tests', () {
    test('badgeType returns playPlus when valid and not expired', () {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final contact = Contact(
        id: '1',
        name: 'Alice',
        keyHash: 'alice_hash',
        relayUrl: 'https://api.wiltkey.org',
        isPrivateNode: false,
        maxBufferBytes: 1000,
        remainingBufferBytes: 1000,
        peerRemainingBufferBytes: 1000,
        lastActivity: DateTime.now(),
        clientAttestation: 'play_plus',
        attestationExpiresAt: nowSec + 86400 * 7,
      );

      expect(contact.badgeType, equals(ClientBadgeType.playPlus));
      expect(contact.isAttestationValid, isTrue);
    });

    test('badgeType returns playOfficial when valid and not expired', () {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final contact = Contact(
        id: '2',
        name: 'Bob',
        keyHash: 'bob_hash',
        relayUrl: 'https://api.wiltkey.org',
        isPrivateNode: false,
        maxBufferBytes: 1000,
        remainingBufferBytes: 1000,
        peerRemainingBufferBytes: 1000,
        lastActivity: DateTime.now(),
        clientAttestation: 'play_official',
        attestationExpiresAt: nowSec + 86400 * 7,
      );

      expect(contact.badgeType, equals(ClientBadgeType.playOfficial));
      expect(contact.isAttestationValid, isTrue);
    });

    test('badgeType returns tinkerer when attestation is expired', () {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final contact = Contact(
        id: '3',
        name: 'Charlie',
        keyHash: 'charlie_hash',
        relayUrl: 'https://api.wiltkey.org',
        isPrivateNode: false,
        maxBufferBytes: 1000,
        remainingBufferBytes: 1000,
        peerRemainingBufferBytes: 1000,
        lastActivity: DateTime.now(),
        clientAttestation: 'play_official',
        attestationExpiresAt: nowSec - 100, // Expired
      );

      expect(contact.badgeType, equals(ClientBadgeType.tinkerer));
      expect(contact.isAttestationValid, isFalse);
    });

    test('badgeType returns tinkerer when clientAttestation is null or unverified', () {
      final contact = Contact(
        id: '4',
        name: 'David',
        keyHash: 'david_hash',
        relayUrl: 'https://api.wiltkey.org',
        isPrivateNode: false,
        maxBufferBytes: 1000,
        remainingBufferBytes: 1000,
        peerRemainingBufferBytes: 1000,
        lastActivity: DateTime.now(),
      );

      expect(contact.badgeType, equals(ClientBadgeType.tinkerer));
    });
  });

  group('IntegrityAttestationManager Offline Verification', () {
    late ed25519.KeyPair relayKeyPair;
    late String relayPubHex;

    setUp(() {
      relayKeyPair = ed25519.generateKey();
      relayPubHex = _bytesToHex(relayKeyPair.publicKey.bytes);
    });

    test('verifies valid relay signed attestation cert', () {
      final userId = 'user_abc123';
      final clientType = 'play_plus';
      final issuedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiresAt = issuedAt + 86400 * 7;

      final message = 'WILTKEY_ATTESTATION:$userId:$clientType:$issuedAt:$expiresAt';
      final sigBytes = ed25519.sign(relayKeyPair.privateKey, utf8.encode(message));
      final relaySigHex = _bytesToHex(sigBytes);

      final cert = {
        'user_id': userId,
        'client_type': clientType,
        'issued_at': issuedAt,
        'expires_at': expiresAt,
        'relay_signature': relaySigHex,
        'relay_public_key': relayPubHex,
      };

      final verified = IntegrityAttestationManager.verifyAttestation(cert, expectedUserId: userId);
      expect(verified, isTrue);
    });

    test('rejects attestation cert with invalid or tampered signature', () {
      final userId = 'user_abc123';
      final clientType = 'play_official';
      final issuedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiresAt = issuedAt + 86400 * 7;

      final message = 'WILTKEY_ATTESTATION:$userId:$clientType:$issuedAt:$expiresAt';
      final sigBytes = ed25519.sign(relayKeyPair.privateKey, utf8.encode(message));
      final relaySigHex = _bytesToHex(sigBytes);

      final tamperedCert = {
        'user_id': userId,
        'client_type': 'play_plus', // Tampered client type
        'issued_at': issuedAt,
        'expires_at': expiresAt,
        'relay_signature': relaySigHex,
        'relay_public_key': relayPubHex,
      };

      final verified = IntegrityAttestationManager.verifyAttestation(tamperedCert, expectedUserId: userId);
      expect(verified, isFalse);
    });

    test('rejects expired attestation cert', () {
      final userId = 'user_abc123';
      final clientType = 'play_official';
      final issuedAt = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 86400 * 10;
      final expiresAt = issuedAt + 86400 * 7; // Expired 3 days ago

      final message = 'WILTKEY_ATTESTATION:$userId:$clientType:$issuedAt:$expiresAt';
      final sigBytes = ed25519.sign(relayKeyPair.privateKey, utf8.encode(message));
      final relaySigHex = _bytesToHex(sigBytes);

      final expiredCert = {
        'user_id': userId,
        'client_type': clientType,
        'issued_at': issuedAt,
        'expires_at': expiresAt,
        'relay_signature': relaySigHex,
        'relay_public_key': relayPubHex,
      };

      final verified = IntegrityAttestationManager.verifyAttestation(expiredCert, expectedUserId: userId);
      expect(verified, isFalse);
    });

    test('rejects attestation cert with mismatched user_id', () {
      final userId = 'user_abc123';
      final clientType = 'play_official';
      final issuedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiresAt = issuedAt + 86400 * 7;

      final message = 'WILTKEY_ATTESTATION:$userId:$clientType:$issuedAt:$expiresAt';
      final sigBytes = ed25519.sign(relayKeyPair.privateKey, utf8.encode(message));
      final relaySigHex = _bytesToHex(sigBytes);

      final cert = {
        'user_id': userId,
        'client_type': clientType,
        'issued_at': issuedAt,
        'expires_at': expiresAt,
        'relay_signature': relaySigHex,
        'relay_public_key': relayPubHex,
      };

      final verified = IntegrityAttestationManager.verifyAttestation(cert, expectedUserId: 'different_user');
      expect(verified, isFalse);
    });

    test('rejects attestation signed by untrusted relay public key when anchor is enforced', () {
      final attackerKey = ed25519.generateKey();
      final attackerPubHex = _bytesToHex(attackerKey.publicKey.bytes);

      final userId = 'user_attacker';
      final clientType = 'play_plus';
      final issuedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiresAt = issuedAt + 86400 * 7;

      final message = 'WILTKEY_ATTESTATION:$userId:$clientType:$issuedAt:$expiresAt';
      final sigBytes = ed25519.sign(attackerKey.privateKey, utf8.encode(message));
      final relaySigHex = _bytesToHex(sigBytes);

      final cert = {
        'user_id': userId,
        'client_type': clientType,
        'issued_at': issuedAt,
        'expires_at': expiresAt,
        'relay_signature': relaySigHex,
        'relay_public_key': attackerPubHex,
      };

      // When trustedRelayPublicKey is the official relay, attacker's key is rejected
      final verified = IntegrityAttestationManager.verifyAttestation(
        cert,
        expectedUserId: userId,
        trustedRelayPublicKey: relayPubHex,
      );
      expect(verified, isFalse);
    });
  });
}

String _bytesToHex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
