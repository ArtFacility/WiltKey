import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiltkey_client/core/network/pow_solver.dart';

void main() {
  test('solvePoWSync matches the relay VerifyPoW layout exactly', () {
    // The relay (pow.go) hashes fmt.Sprintf("%s%d%s", challenge, nonce,
    // payload) as UTF-8 and requires [difficulty] leading hex zeros. The
    // solver must produce a nonce that satisfies that exact byte layout —
    // any divergence (padded nonce, different order) would fail issuance.
    const challenge = 'deadbeefcafebabe0123456789abcdef';
    final payload = 'aa' * 32; // pubkey hex shape
    const difficulty = 4;

    final nonce = solvePoWSync(challenge, payload, difficulty);
    expect(nonce, greaterThanOrEqualTo(0));

    // Independent recomputation using the exact Go layout.
    final data = utf8.encode('$challenge$nonce$payload');
    final digest = sha256.convert(data).toString();
    expect(digest.startsWith('0' * difficulty), isTrue);
  });

  test('solvePoW with onProgress solves identically and reports progress',
      () async {
    const challenge = 'deadbeefcafebabe0123456789abcdef';
    final payload = 'aa' * 32;
    const difficulty = 4;

    final progress = <int>[];
    final nonce = await solvePoW(
      challenge: challenge,
      payload: payload,
      difficulty: difficulty,
      onProgress: (iterations, zeroBits) => progress.add(iterations),
    );

    // The isolate path must agree with the byte-exact sync solver.
    final syncNonce = solvePoWSync(challenge, payload, difficulty);
    expect(nonce, equals(syncNonce));

    // 16^4 ≈ 65k expected iterations, batch is 16384 → progress must have
    // fired, strictly increasing.
    expect(progress, isNotEmpty);
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i], greaterThan(progress[i - 1]));
    }
  });

  test('solutions are payload-bound (cannot be transferred between identities)',
      () {
    const challenge = 'cafebabe';
    final payloadA = '11' * 32;
    final payloadB = '22' * 32;

    // Deterministic: the SAME nonce over a DIFFERENT payload hashes
    // differently, so a solved challenge is bound to the presenting pubkey.
    final digestA =
        sha256.convert(utf8.encode('${challenge}0$payloadA')).toString();
    final digestB =
        sha256.convert(utf8.encode('${challenge}0$payloadB')).toString();
    expect(digestA, isNot(equals(digestB)));
    expect(
      digestB.startsWith('0' * 8),
      isFalse,
      reason: 'an accidental preimage would undermine the binding',
    );
  });
}
