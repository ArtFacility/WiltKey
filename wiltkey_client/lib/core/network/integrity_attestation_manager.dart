import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed25519;

import '../build_flavor.dart';

/// Manages Google Play Integrity hardware attestation and relay-signed verification certs.
class IntegrityAttestationManager {
  static const MethodChannel _integrityChannel = MethodChannel('wiltkey/integrity');
  static const String _kCachedCertKey = 'wk_client_attestation_cert_v1';

  static final IntegrityAttestationManager instance = IntegrityAttestationManager._();
  IntegrityAttestationManager._();

  Map<String, dynamic>? _cachedCert;

  /// Loads cached attestation certificate from persistent storage.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCachedCertKey);
      if (raw != null && raw.isNotEmpty) {
        final parsed = jsonDecode(raw) as Map<String, dynamic>;
        if (verifyAttestation(parsed)) {
          _cachedCert = parsed;
        }
      }
    } catch (e) {
      debugPrint('[Integrity] Error loading cached attestation: $e');
    }
  }

  /// Returns our active, verified attestation certificate, or null if unverified / FOSS.
  Map<String, dynamic>? get cachedCert => _cachedCert;

  /// Requests hardware/binary token from Google Play Integrity API via Android bridge.
  static Future<String?> requestNativeIntegrityToken(String nonce) async {
    if (!kPlayStore) return null;
    try {
      final token = await _integrityChannel.invokeMethod<String>(
        'requestIntegrityToken',
        {'nonce': nonce},
      );
      return token;
    } catch (e) {
      debugPrint('[Integrity] Native Play Integrity token error: $e');
      return null;
    }
  }

  /// Refreshes attestation against the relay server if expired or nearing expiry (within 1 day).
  Future<Map<String, dynamic>?> syncAttestation({
    required String relayUrl,
    required String userId,
    required String publicKeyHex,
    required String Function(String message) signMessage,
    bool force = false,
  }) async {
    if (!kPlayStore) return null;

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Check if existing cert is still comfortably valid (> 24 hours remaining)
    if (!force && _cachedCert != null) {
      final expiresAt = _cachedCert!['expires_at'] as int? ?? 0;
      if (expiresAt - nowSec > 86400) {
        return _cachedCert;
      }
    }

    try {
      final base = Uri.parse(relayUrl);
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);

      // 1. Request Challenge Nonce from Relay
      final challengeUri = base.replace(
        path: base.path.endsWith('/')
            ? '${base.path}api/v1/integrity/challenge'
            : '${base.path}/api/v1/integrity/challenge',
      );

      final challengeSig = signMessage('INTEGRITY_CHALLENGE:$userId:$nowSec');
      final challengeReq = await client.postUrl(challengeUri);
      challengeReq.headers.contentType = ContentType.json;
      challengeReq.write(jsonEncode({
        'user_id': userId,
        'pubkey': publicKeyHex,
        'signature': challengeSig,
        'timestamp': nowSec,
      }));

      final challengeRes = await challengeReq.close();
      final challengeBody = await challengeRes.transform(utf8.decoder).join();
      if (challengeRes.statusCode != HttpStatus.ok) {
        debugPrint('[Integrity] Challenge failed (${challengeRes.statusCode}): $challengeBody');
        return _cachedCert;
      }

      final challengeData = jsonDecode(challengeBody) as Map<String, dynamic>;
      final expectedNonce = challengeData['expected_nonce'] as String?;
      if (expectedNonce == null || expectedNonce.isEmpty) {
        debugPrint('[Integrity] Empty expected nonce from challenge');
        return _cachedCert;
      }

      // 2. Request Integrity Token from Google Play Integrity API
      final integrityToken = await requestNativeIntegrityToken(expectedNonce);
      if (integrityToken == null || integrityToken.isEmpty) {
        debugPrint('[Integrity] Failed to obtain Play Integrity token from device');
        return _cachedCert;
      }

      // 3. Submit Token to Relay for Attestation Certificate
      final attestUri = base.replace(
        path: base.path.endsWith('/')
            ? '${base.path}api/v1/integrity/attest'
            : '${base.path}/api/v1/integrity/attest',
      );

      final tokenHash = sha256.convert(utf8.encode(integrityToken)).toString();
      final attestNowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final attestSig = signMessage('INTEGRITY_ATTEST:$userId:$tokenHash:$attestNowSec');

      final attestReq = await client.postUrl(attestUri);
      attestReq.headers.contentType = ContentType.json;
      attestReq.write(jsonEncode({
        'user_id': userId,
        'pubkey': publicKeyHex,
        'integrity_token': integrityToken,
        'signature': attestSig,
        'timestamp': attestNowSec,
      }));

      final attestRes = await attestReq.close();
      final attestBody = await attestRes.transform(utf8.decoder).join();
      if (attestRes.statusCode != HttpStatus.ok) {
        debugPrint('[Integrity] Attestation failed (${attestRes.statusCode}): $attestBody');
        return _cachedCert;
      }

      final certData = jsonDecode(attestBody) as Map<String, dynamic>;
      if (verifyAttestation(certData, expectedUserId: userId)) {
        _cachedCert = certData;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kCachedCertKey, jsonEncode(certData));
        debugPrint('[Integrity] Successfully refreshed and verified Play attestation cert: ${certData['client_type']}');
        return _cachedCert;
      } else {
        debugPrint('[Integrity] Relay returned invalid attestation signature');
      }
    } catch (e) {
      debugPrint('[Integrity] Error during attestation sync: $e');
    }
    return _cachedCert;
  }

  /// Known trusted relay attestation public keys (hex).
  static final Set<String> trustedRelayPublicKeys = <String>{};

  /// Register a trusted relay attestation public key.
  static void addTrustedRelayKey(String pubkeyHex) {
    if (pubkeyHex.isNotEmpty) {
      trustedRelayPublicKeys.add(pubkeyHex.toLowerCase());
    }
  }

  /// Verifies an Ed25519-signed attestation certificate offline.
  static bool verifyAttestation(
    Map<String, dynamic> cert, {
    String? expectedUserId,
    String? trustedRelayPublicKey,
  }) {
    try {
      final userId = cert['user_id'] as String?;
      final clientType = cert['client_type'] as String?;
      final issuedAt = cert['issued_at'] as int?;
      final expiresAt = cert['expires_at'] as int?;
      final relaySigHex = cert['relay_signature'] as String?;
      final relayPubHex = (cert['relay_public_key'] as String?)?.toLowerCase();

      if (userId == null || clientType == null || issuedAt == null || expiresAt == null ||
          relaySigHex == null || relayPubHex == null) {
        return false;
      }

      if (expectedUserId != null && expectedUserId != userId) {
        return false;
      }

      // Check trusted relay public key anchor if specified or configured
      if (trustedRelayPublicKey != null) {
        if (relayPubHex != trustedRelayPublicKey.toLowerCase()) {
          return false;
        }
      } else if (trustedRelayPublicKeys.isNotEmpty) {
        if (!trustedRelayPublicKeys.contains(relayPubHex)) {
          return false;
        }
      }

      // Check expiry
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (nowSec > expiresAt) {
        return false;
      }

      // Verify Ed25519 signature
      final pubBytes = _hexToBytes(relayPubHex);
      final sigBytes = _hexToBytes(relaySigHex);
      if (pubBytes.length != 32 || sigBytes.length != 64) {
        return false;
      }

      final pubKey = ed25519.PublicKey(pubBytes);
      final message = 'WILTKEY_ATTESTATION:$userId:$clientType:$issuedAt:$expiresAt';
      return ed25519.verify(pubKey, utf8.encode(message), sigBytes);
    } catch (e) {
      debugPrint('[Integrity] Attestation verification exception: $e');
      return false;
    }
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
