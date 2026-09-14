import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Solves the relay's device-token issuance challenge. The relay (pow.go)
/// defines a solution as: sha256(utf8(challenge + decimalNonce + payload))
/// whose hex digest starts with [difficulty] leading '0' characters. The
/// payload is our own pubkey hex, which binds a solved challenge to THIS
/// identity (a solution can't be transferred between keypairs) and to THIS
/// connection (the challenge is fresh per connect).
///
/// Runs in a background isolate so the UI keeps painting during the (one-time,
/// per-install) search. Difficulty 5 ≈ ~1M hashes ≈ a couple of seconds.
/// With [onProgress], periodic (iterations, best-zero-bits) updates are
/// forwarded to the caller (drives the onboarding progress bar).
Future<int> solvePoW({
  required String challenge,
  required String payload,
  required int difficulty,
  void Function(int iterations, int zeroBits)? onProgress,
}) {
  if (onProgress == null) {
    return Isolate.run(() => solvePoWSync(challenge, payload, difficulty));
  }
  return _solvePoWIsolate(challenge, payload, difficulty, onProgress);
}

/// Every N iterations the solver isolate reports progress. Small enough for a
/// smooth bar, large enough that message passing never dominates solve time.
const int _kPowProgressBatch = 16384;

void _powWorker(List<Object> args) {
  final challenge = args[0] as String;
  final payload = args[1] as String;
  final difficulty = args[2] as int;
  final port = args[3] as SendPort;
  try {
    final nonce = solvePoWSync(challenge, payload, difficulty, progress: port);
    // Isolate.exit transfers the result cheaply and tears the isolate down.
    Isolate.exit(port, nonce);
  } catch (e) {
    port.send(['POW_ERROR', e.toString()]);
  }
}

Future<int> _solvePoWIsolate(
  String challenge,
  String payload,
  int difficulty,
  void Function(int iterations, int zeroBits) onProgress,
) {
  final completer = Completer<int>();
  final port = ReceivePort();
  final errors = ReceivePort();
  StreamSubscription<dynamic>? portSub;
  StreamSubscription<dynamic>? errSub;

  void cleanup() {
    portSub?.cancel();
    errSub?.cancel();
    errors.close();
    port.close();
  }

  void fail(Object e) {
    if (!completer.isCompleted) completer.completeError(e);
    cleanup();
  }

  errSub = errors.listen((msg) {
    fail(Exception('PoW isolate failed: $msg'));
  });

  portSub = port.listen((msg) {
    if (msg is int) {
      if (!completer.isCompleted) completer.complete(msg);
      cleanup();
    } else if (msg is List && msg.length == 2 && msg[0] is int) {
      onProgress(msg[0] as int, msg[1] as int);
    } else if (msg is List && msg.isNotEmpty && msg[0] == 'POW_ERROR') {
      fail(Exception(msg[1].toString()));
    }
  });

  Isolate.spawn(
    _powWorker,
    <Object>[challenge, payload, difficulty, port.sendPort],
    onError: errors.sendPort,
    errorsAreFatal: false,
  ).then((_) {}, onError: fail);

  return completer.future;
}

/// Byte-exact reference solver (golden-tested). Optionally reports progress on
/// [progress] every [_kPowProgressBatch] iterations as [iterations, zeroBits].
int solvePoWSync(
  String challenge,
  String payload,
  int difficulty, {
  SendPort? progress,
}) {
  final challengeBytes = utf8.encode(challenge);
  final payloadBytes = utf8.encode(payload);
  final challengeLen = challengeBytes.length;
  final payloadLen = payloadBytes.length;

  // Scratch buffer: challenge | (≤20 nonce digits) | payload, with the payload
  // re-copied to sit immediately after the (variable-length) nonce each
  // iteration — the hashed layout must stay byte-exact with the relay's
  // challenge + decimalNonce + payload concatenation.
  final buf = Uint8List(challengeLen + 20 + payloadLen);
  buf.setRange(0, challengeLen, challengeBytes);
  final nonceScratch = Uint8List(20);

  var nonce = 0;
  Uint8List digest = Uint8List(32);
  while (true) {
    final digits = _decimalDigits(nonce, nonceScratch);
    final payloadStart = challengeLen + digits;
    buf.setRange(challengeLen, payloadStart, nonceScratch);
    buf.setRange(payloadStart, payloadStart + payloadLen, payloadBytes);
    digest.setAll(
      0,
      sha256.convert(Uint8List.sublistView(buf, 0, payloadStart + payloadLen)).bytes,
    );
    if (_leadingZeroHexChars(digest) >= difficulty) {
      return nonce;
    }
    nonce++;
    if (progress != null && (nonce % _kPowProgressBatch) == 0) {
      progress.send(<Object>[nonce, _leadingZeroHexChars(digest) * 4]);
    }
  }
}

/// Writes the decimal representation of [value] into [scratch] (most
/// significant digit first, no padding) and returns the digit count.
int _decimalDigits(int value, Uint8List scratch) {
  var len = 0;
  if (value == 0) {
    scratch[0] = 0x30;
    return 1;
  }
  while (value > 0) {
    scratch[len++] = 0x30 + (value % 10);
    value ~/= 10;
  }
  // Digits were produced least-significant first — reverse in place.
  for (var i = 0; i < len ~/ 2; i++) {
    final t = scratch[i];
    scratch[i] = scratch[len - 1 - i];
    scratch[len - 1 - i] = t;
  }
  return len;
}

/// Number of leading '0' characters the hex encoding of [digest] would have.
int _leadingZeroHexChars(Uint8List digest) {
  var chars = 0;
  for (var i = 0; i < digest.length; i++) {
    final b = digest[i];
    if ((b >> 4) != 0) return chars;
    chars++;
    if ((b & 0xF) != 0) return chars;
    chars++;
  }
  return chars;
}
