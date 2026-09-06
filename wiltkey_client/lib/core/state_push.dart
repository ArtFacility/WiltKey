part of 'state.dart';

/// Play-flavor FCM token registration with the relay.
///
/// Only ever does anything when [kFcmEnabled] (the Play build) AND the user is in
/// Instant mode. On the FOSS build every method here short-circuits, so no token
/// leaves the device and the relay never learns of one. Auth mirrors the server's
/// push endpoints: a fresh unix timestamp + an Ed25519 signature proving we own
/// the identity, so a device can only register/clear its OWN token.
extension AppStatePush on AppState {
  /// Register (or refresh) our FCM token with the relay so it can send a
  /// content-free wake-up ping when a message queues while we're offline.
  Future<void> registerPushToken() async {
    if (!kFcmEnabled) return;
    final token = await PushChannel.getToken();
    if (token == null) {
      log('[Push] PushChannel.getToken() returned null (Google Play Services unavailable or token not yet ready)');
      return;
    }
    log('[Push] Registering FCM token with relay for $userId (${token.length} chars)');
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final sig = signMessage('$userId:$ts:$token');
    await _postPush('register', {
      'id': userId,
      'pubkey': publicKeyHex,
      'timestamp': ts,
      'sig': sig,
      'token': token,
      'device_token': await getDeviceToken(),
    });
  }

  /// Clear our token on the relay (mode left Instant, or nuke) and locally, so the
  /// device stops being wakeable by FCM.
  Future<void> unregisterPushToken() async {
    if (!kFcmEnabled) return;
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final sig = signMessage('$userId:$ts');
    await _postPush('unregister', {
      'id': userId,
      'pubkey': publicKeyHex,
      'timestamp': ts,
      'sig': sig,
      'device_token': await getDeviceToken(),
    });
    await PushChannel.deleteToken();
  }

  /// Re-assert registration whenever it should be active (called on every WS
  /// connect). Cheap no-op unless we're a Play build in Instant mode.
  void refreshPushRegistration() {
    if (kFcmEnabled && notificationMode == NotificationMode.instant) {
      registerPushToken();
    }
  }

  /// One-time upgrade healing. Users who ran the OLD foreground-service "Instant"
  /// mode and updated in place to the FCM-backed build keep their stored
  /// `notificationMode == instant`, but the FCM wake-up was never wired up — that
  /// only ever happened inside [setNotificationMode], which they never re-ran.
  /// So Instant looked selected yet no push arrived until they toggled the mode
  /// off, killed the app, and back on by hand.
  ///
  /// This re-runs that same setup exactly once — request the notification
  /// permission and register the FCM token — then records that it's done. A no-op
  /// on the FOSS flavor (no FCM at all) and on every launch after the first.
  Future<void> reconcileInstantModeAfterUpgrade() async {
    if (!kFcmEnabled) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(kPrefPushMigrationDone) == true) return;
    if (notificationMode == NotificationMode.instant) {
      await WiltkeyNotifications.requestPermission();
      await registerPushToken();
      log('[Push] Auto-wired FCM Instant after in-place upgrade.');
    }
    await prefs.setBool(kPrefPushMigrationDone, true);
  }

  Future<void> _postPush(String action, Map<String, dynamic> body) async {
    try {
      final base = Uri.parse(activeRelayUrl);
      final uri = base.replace(
        path: base.path.endsWith('/')
            ? '${base.path}api/v1/push/$action'
            : '${base.path}/api/v1/push/$action',
      );
      final client = HttpClient();
      try {
        final req = await client
            .postUrl(uri)
            .timeout(const Duration(seconds: 15));
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(jsonEncode(body)));
        final resp = await req.close().timeout(const Duration(seconds: 15));
        await resp.drain<void>();
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          log('[Push] $action OK');
        } else {
          log('[Push] $action rejected: HTTP ${resp.statusCode}');
        }
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      log('[Push] $action failed: $e');
    }
  }
}
