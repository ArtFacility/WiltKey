part of 'state.dart';

/// Syncs the WiltKey Plus subscription to the relay so it can grant the
/// server-side perks (72h offline hold + >=5MB file transfers).
///
/// Purely local cosmetics (themes/palettes/borders/pad size) are gated on-device
/// by [EntitlementService] and never touch the relay. Plus is different: only the
/// relay can enforce the longer hold and the larger file gate, so it must learn
/// which users are subscribers. We tell it by POSTing the Play purchase token,
/// signed by our identity key — the same auth shape as the push endpoints
/// (see [AppStatePush]): a fresh unix timestamp + an Ed25519 signature of
/// `userId:timestamp`, so a device can only ever register its OWN entitlement.
///
/// **Trust note:** the relay currently stores the token on trust (a signed
/// self-declaration). Real Google Play Developer API verification of the token
/// lands in Step 6 (needs the Play service account); until then this is a
/// functional-but-unverified paywall, and the risk is bounded to storage/hold
/// abuse (never message secrecy — payloads stay end-to-end encrypted).
///
/// No-op on FOSS (`kPlayStore` false — no billing, and the official relay is the
/// only one that enforces Plus; a self-hoster sets their own TTLs).
extension AppStateEntitlement on AppState {
  /// Push our current Plus subscription token to the relay, if we have one.
  /// Safe to call repeatedly (launch, resume, post-purchase) — the relay upserts
  /// and re-caches. Silently does nothing when not subscribed or offline.
  Future<void> syncPlusEntitlement() async {
    if (!kPlayStore) return;
    if (!EntitlementService.instance.plusActive) return;

    final token = await EntitlementService.instance.plusPurchaseToken();
    if (token == null || token.isEmpty) return;
    if (publicKeyHex.isEmpty || userId.isEmpty) return;

    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final sig = signMessage('$userId:$ts');
    await _postEntitlement({
      'user_id': userId,
      'pubkey': publicKeyHex,
      'timestamp': ts,
      'signature': sig,
      'purchase_token': token,
    });
  }

  Future<void> _postEntitlement(Map<String, dynamic> body) async {
    try {
      final base = Uri.parse(activeRelayUrl);
      final uri = base.replace(
        path: base.path.endsWith('/')
            ? '${base.path}api/v1/entitlement'
            : '${base.path}/api/v1/entitlement',
      );
      final client = HttpClient();
      try {
        final req =
            await client.postUrl(uri).timeout(const Duration(seconds: 15));
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(jsonEncode(body)));
        final resp = await req.close().timeout(const Duration(seconds: 15));
        await resp.drain<void>();
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          log('[Entitlement] Plus synced to relay OK');
        } else {
          log('[Entitlement] Plus sync rejected: HTTP ${resp.statusCode}');
        }
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      log('[Entitlement] Plus sync failed: $e');
    }
  }
}
