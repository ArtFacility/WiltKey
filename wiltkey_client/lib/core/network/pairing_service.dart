import 'dart:io';
import 'dart:async';
import 'dart:convert';

/// Outcome of a `/pair/init` call — the 6-digit rendezvous PIN the host shows.
class PairInitResult {
  final String pin;
  PairInitResult(this.pin);
}

/// What the joiner learns from `/pair/join`: the host's identity + pad size. The
/// caller MUST verify `sha256(initiatorPub) == the host hash the user pasted`
/// before trusting it — that check is the defense against a relay swapping keys.
class PairJoinResult {
  final String initiatorId;
  final String initiatorPub;
  final int bufferBytes;
  PairJoinResult(this.initiatorId, this.initiatorPub, this.bufferBytes);
}

/// What the host learns from polling `/pair/poll`: whether a joiner has arrived
/// yet and, once joined, their identity/pubkey.
class PairPollResult {
  final String status; // 'pending' | 'joined' | 'expired'
  final String? receiverId;
  final String? receiverPub;
  PairPollResult(this.status, {this.receiverId, this.receiverPub});
}

class PairingService {
  // TEMPORARY (see kRemotePairingTesting): the relay-mediated pairing calls used
  // ONLY by the debug remote-pairing test path. The relay shuttles the two
  // ed25519 public keys + buffer size keyed by PIN; each side derives the same
  // seed = sha256(sorted(pubA+pubB)) locally, exactly as the BLE handshake does.
  static String _clean(String relayUrl) {
    var u = relayUrl.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  /// Host: register our pubkey under a fresh PIN. Returns the PIN to share.
  static Future<PairInitResult> pairInit(
    String relayUrl, {
    required String initiatorId,
    required String pubkey,
    required int bufferBytes,
  }) async {
    final body = await _post('${_clean(relayUrl)}/api/v1/pair/init', {
      'initiator_id': initiatorId,
      'pubkey': pubkey,
      'buffer_bytes': bufferBytes,
    });
    final pin = body['pin'] as String?;
    if (pin == null || pin.isEmpty) {
      throw Exception('Relay did not return a PIN.');
    }
    return PairInitResult(pin);
  }

  /// Joiner: submit our pubkey against a PIN; get the host's identity + pad size.
  /// Throws with a readable message on an invalid/expired PIN or a taken slot.
  static Future<PairJoinResult> pairJoin(
    String relayUrl, {
    required String pin,
    required String receiverId,
    required String pubkey,
  }) async {
    final body = await _post('${_clean(relayUrl)}/api/v1/pair/join', {
      'pin': pin,
      'receiver_id': receiverId,
      'pubkey': pubkey,
    });
    if (body['error'] != null) {
      throw Exception(body['error'].toString());
    }
    final initPub = body['pubkey'] as String?;
    final initId = body['initiator_id'] as String?;
    if (initPub == null || initId == null) {
      throw Exception('Malformed join response from relay.');
    }
    return PairJoinResult(
      initId,
      initPub,
      (body['buffer_bytes'] as num?)?.toInt() ?? 0,
    );
  }

  /// Host: poll for a joiner. Status is 'pending' until one arrives, then
  /// 'joined' (with their id/pubkey), or 'expired' if the PIN lapsed.
  static Future<PairPollResult> pairPoll(
    String relayUrl, {
    required String pin,
    required String initiatorId,
  }) async {
    final uri = Uri.parse(
      '${_clean(relayUrl)}/api/v1/pair/poll',
    ).replace(queryParameters: {'pin': pin, 'id': initiatorId});
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(uri);
      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 200) {
        throw Exception('Poll failed (${resp.statusCode}).');
      }
      final body = jsonDecode(text) as Map<String, dynamic>;
      return PairPollResult(
        (body['status'] as String?) ?? 'expired',
        receiverId: body['receiver_id'] as String?,
        receiverPub: body['pubkey'] as String?,
      );
    } finally {
      client.close();
    }
  }

  /// Host (group invite): upload the encrypted group-invite blob under [pin].
  /// Only valid after the host has polled and learned the joiner's pubkey.
  static Future<void> pairInviteUpload(
    String relayUrl, {
    required String pin,
    required String initiatorId,
    required String blob,
  }) async {
    final body = await _post('${_clean(relayUrl)}/api/v1/pair/invite', {
      'pin': pin,
      'initiator_id': initiatorId,
      'blob': blob,
    });
    if (body['error'] != null) throw Exception(body['error'].toString());
  }

  /// Joiner (group invite): poll for the host's invite blob. Status is 'pending'
  /// until the host posts it, then 'ready' (with [blob]), or 'expired'.
  static Future<({String status, String? blob})> pairInviteFetch(
    String relayUrl, {
    required String pin,
    required String receiverId,
  }) async {
    final uri = Uri.parse(
      '${_clean(relayUrl)}/api/v1/pair/invite',
    ).replace(queryParameters: {'pin': pin, 'receiver_id': receiverId});
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(uri);
      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 200) {
        throw Exception('Invite poll failed (${resp.statusCode}).');
      }
      final body = jsonDecode(text) as Map<String, dynamic>;
      return (
        status: (body['status'] as String?) ?? 'expired',
        blob: body['blob'] as String?,
      );
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> _post(
    String url,
    Map<String, dynamic> json,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.postUrl(Uri.parse(url));
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.add(utf8.encode(jsonEncode(json)));
      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      // 404 carries a JSON {"error":...} we want to surface, so parse the body
      // regardless of status and let the caller decide.
      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {
        parsed = {};
      }
      if (resp.statusCode != 200 && parsed['error'] == null) {
        throw Exception('Relay error (${resp.statusCode}).');
      }
      return parsed;
    } finally {
      client.close();
    }
  }

  static Future<int?> pingRelay(String relayUrl) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);
    try {
      final stopwatch = Stopwatch()..start();
      // Normalize URL (strip trailing slashes, add ping suffix if needed)
      var cleanUrl = relayUrl.trim();
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }
      final request = await client.getUrl(Uri.parse('$cleanUrl/ping'));
      final response = await request.close();
      stopwatch.stop();
      if (response.statusCode == 200) {
        return stopwatch.elapsedMilliseconds;
      }
    } catch (e) {
      print('Relay ping failed: $e');
    } finally {
      client.close();
    }
    return null;
  }
}
