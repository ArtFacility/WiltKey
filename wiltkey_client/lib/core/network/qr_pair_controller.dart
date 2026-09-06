// Offline QR quick-connect: the relay-free successor to the deleted
// /api/v1/pair/* endpoints. Two devices in physical proximity scan EACH
// OTHER's QR codes; each QR carries the scanner's own ed25519 public key, so
// after one scan in each direction both sides hold both pubkeys and derive the
// identical pairwise seed locally — the exact same derivation as the BLE
// handshake (sha256 of the sorted pubkey pair). No PIN, no relay round-trip,
// and no relay in the pairing trust path: proximity is the only channel, and
// a hostile relay can no longer attempt key-substitution during pairing.
//
// The result is always a 7-day Time Wilt 1:1 chat (same template as before).
// Byte-budget (OTP pad) chats still require in-person BLE pairing — a QR pair
// must never recharge or recreate a pad file.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../state.dart';
import '../models.dart';

/// QR payload version marker. v2 = offline two-scan (pubkey + fresh nonce in
/// the QR). The nonce is what makes the stream seed SECRET: the deterministic
/// pubkey derivation alone is publicly recomputable by anyone holding both
/// pubkeys — including the relay, which sees every pubkey in the AUTH frame.
const int kQrPairVersion = 2;

enum QrPairPhase { idle, scanned, generating, success, error }

/// Derives the offline QR pairing stream seed from BOTH devices' fresh nonces
/// and pubkeys. Every component is fixed-length hex (64 chars), so the
/// concatenation is unambiguous; both sorts make the derivation role-free.
/// Publicly computable ONLY with both nonces — and nonces never leave the
/// proximity channel (they exist only inside the two scanned QR codes), so
/// the relay — which knows both pubkeys from AUTH — cannot derive this seed.
String deriveQrPairSeedHex({
  required String nonceA,
  required String nonceB,
  required String pubA,
  required String pubB,
}) {
  final nonces = [nonceA.toLowerCase(), nonceB.toLowerCase()]..sort();
  final pubs = [pubA.toLowerCase(), pubB.toLowerCase()]..sort();
  return sha256
      .convert(utf8.encode(nonces[0] + nonces[1] + pubs[0] + pubs[1]))
      .toString();
}

class QrPairController extends ChangeNotifier {
  final AppState appState = AppState();

  QrPairController() {
    _regenerateNonce();
  }

  QrPairPhase phase = QrPairPhase.idle;

  /// Human status line for the current phase / error.
  String status = '';

  /// Populated when [phase] is error.
  String? error;

  /// The contact created on success (drives the "go to chat" navigation).
  Contact? result;

  /// Peer captured from their QR (awaiting them to scan ours).
  String? _peerPub;
  String? _peerId;
  String? _peerNonce;

  /// OUR fresh random 256-bit nonce, printed inside our QR. Combined with the
  /// peer's nonce (after the mutual scan) into the stream seed — see
  /// [deriveQrPairSeedHex]. Never transmitted anywhere else.
  String _myNonceHex = '';

  void _regenerateNonce() {
    _myNonceHex = List.generate(
      32,
      (_) => Random.secure().nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Our own QR payload — carries our pubkey AND our fresh nonce, so the
  /// mutual scan exchange gives both sides everything needed to derive a
  /// SECRET stream seed locally.
  String get myQrPayload {
    final uri = Uri(
      scheme: 'wiltkey',
      host: 'pair',
      queryParameters: {
        'v': '$kQrPairVersion',
        'pk': appState.publicKeyHex,
        'uid': appState.userId,
        'n': _myNonceHex,
        'type': 'timewilt',
      },
    );
    return uri.toString();
  }

  /// Validate a scanned QR URI and capture the peer. Requires the v2 offline
  /// format (both v1 relay-mediated and malformed codes are rejected — the
  /// endpoints they relied on no longer exist).
  Future<void> handleScannedUri(Uri uri) async {
    if (phase == QrPairPhase.generating) return;

    if (uri.queryParameters['v'] != '$kQrPairVersion') {
      _fail('qrConnectOutdatedCode');
      return;
    }
    final pk = uri.queryParameters['pk'] ?? '';
    final uid = uri.queryParameters['uid'] ?? '';
    final nonce = uri.queryParameters['n'] ?? '';
    if (pk.length != 64 || !_isHex(pk) || uid.length != 64) {
      _fail('Invalid WiltKey QR code.');
      return;
    }
    if (nonce.length != 64 || !_isHex(nonce)) {
      // A v2 code without a fresh nonce would yield a publicly-derivable
      // seed — refuse rather than pair with relay-transparent key material.
      _fail('Invalid WiltKey QR code.');
      return;
    }
    // Normalize before hashing/sorting: canonical pubkeys are lowercase hex,
    // and both devices must feed the IDENTICAL string into the seed derivation
    // (a crafted uppercase payload would otherwise yield divergent seeds).
    final normPk = pk.toLowerCase();
    // Integrity: the id in the QR must be the hash of the key it ships with.
    // A garbled/crafted code can never bind routing to a different key.
    if (sha256.convert(_hexToBytes(normPk)).toString() != uid.toLowerCase()) {
      _fail('Invalid WiltKey QR code.');
      return;
    }
    if (normPk == appState.publicKeyHex) {
      _fail('qrConnectOwnCode');
      return;
    }

    final peerId = uid.toLowerCase();
    // Fail closed on ANY existing contact with this identity — not just OTP
    // pads. Upserting a Time Wilt contact resets its keystream offsets while
    // the (possibly archived) chat history is retained on disk, which would
    // re-encrypt new messages into already-burned keystream ranges. Refreshing
    // an existing chat (recharge/revive) stays in-person BLE only.
    final existingIndex =
        appState.contacts.indexWhere((c) => c.keyHash == peerId);
    if (existingIndex != -1) {
      _fail('qrConnectAlreadyPaired');
      return;
    }

    _peerPub = normPk;
    _peerId = peerId;
    _peerNonce = nonce.toLowerCase();
    phase = QrPairPhase.scanned;
    status = '';
    error = null;
    notifyListeners();
  }

  /// Finalize the pair: derive the pairwise seed, create the 7-day Time Wilt
  /// contact, and push our profile over the encrypted meta channel. The peer
  /// finalizes symmetrically on their own device.
  Future<void> finalizePair() async {
    final peerPub = _peerPub;
    final peerId = _peerId;
    if (peerPub == null || peerId == null) {
      _fail('Invalid WiltKey QR code.');
      return;
    }

    phase = QrPairPhase.generating;
    status = 'Setting up 7-day Time Wilt chat…';
    notifyListeners();

    try {
      // SECRET stream seed: derived from both devices' fresh nonces (which
      // only ever existed inside the two scanned QR codes) bound to both
      // pubkeys. The relay knows the pubkeys but not the nonces — it cannot
      // recompute this. Same value on both devices (role-free sorting).
      final pairSeed = deriveQrPairSeedHex(
        nonceA: _myNonceHex,
        nonceB: _peerNonce!,
        pubA: appState.publicKeyHex,
        pubB: peerPub,
      );
      // The deterministic pubkey derivation (below) is now vestigial — kept
      // only as the upsert's never-used fallback parameter.
      final pair = [appState.publicKeyHex, peerPub]..sort();
      final derivedSeed =
          sha256.convert(utf8.encode(pair[0] + pair[1])).toString();

      final placeholder = 'Contact ${peerId.substring(0, 6)}';
      final wiltExpiresAt =
          DateTime.now().toUtc().add(const Duration(days: 7));

      await appState.addOrRechargeTimeWiltContact(
        placeholder,
        appState.activeRelayUrl,
        peerId,
        derivedSeed,
        wiltExpiresAt,
        freshSeedHex: pairSeed,
      );

      final contact = appState.contacts.firstWhere(
        (c) => c.keyHash == peerId,
        orElse: () => throw Exception('Contact vanished after pairing.'),
      );

      // Push OUR profile (name/nick/avatar) to the peer over the encrypted
      // meta channel; theirs arrives symmetrically and backfills the name.
      await appState.sendChatInfoUpdate(contact);

      result = contact;
      phase = QrPairPhase.success;
      status = 'Connected! 7-day Time Wilt chat ready.';
      // The nonce was just burned into this pair's seed — a subsequent
      // session (different peer) must advertise fresh material.
      _regenerateNonce();
      notifyListeners();
    } catch (e) {
      _fail('Connection failed: $e');
    }
  }

  /// Re-scan support: forget the captured peer and go back to scanning.
  void reset() {
    _peerPub = null;
    _peerId = null;
    _peerNonce = null;
    // Fresh nonce for the next attempt — the old one was printed in a QR that
    // has been shown around; never reuse nonce material across sessions.
    _regenerateNonce();
    phase = QrPairPhase.idle;
    status = '';
    error = null;
    result = null;
    notifyListeners();
  }

  void _fail(String message) {
    if (_disposed) return;
    _peerPub = null;
    _peerId = null;
    _peerNonce = null;
    // Burn the advertised nonce too — it was shown in a QR that may have been
    // captured; never reuse nonce material across sessions.
    _regenerateNonce();
    error = message;
    status = message;
    phase = QrPairPhase.error;
    notifyListeners();
  }

  bool _isHex(String s) =>
      s.toLowerCase().contains(RegExp(r'^[0-9a-f]+$'));

  List<int> _hexToBytes(String hex) {
    final out = <int>[];
    for (int i = 0; i + 1 < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
