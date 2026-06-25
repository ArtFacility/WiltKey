part of 'state.dart';

extension AppStateAuth on AppState {
  static String deriveKey(String pin, String saltHex) {
    List<int> key = utf8.encode(pin + saltHex);
    for (int i = 0; i < 5000; i++) {
      key = sha256.convert(key).bytes;
    }
    return key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Validates the PIN, then loads + decrypts everything. [onValidated] fires the
  /// instant the PIN is confirmed correct (a fast step) — BEFORE the slower data
  /// load — so the UI can start the unlock animation as a cover over that wait and
  /// over the PinLockScreen→AppShell swap, eliminating the flash of the prior
  /// screen. It is NOT called for a wrong PIN.
  Future<bool> unlockApp(String pin, {VoidCallback? onValidated}) async {
    final data = await _persistence.loadState();
    final pinSalt = data['pinSalt'] as String?;
    final pinValidationHash = data['pinValidationHash'] as String?;

    if (pinSalt == null || pinValidationHash == null) return false;

    final derivedKey = deriveKey(pin, pinSalt);
    final derivedHash = sha256.convert(utf8.encode(derivedKey)).toString();

    if (derivedHash != pinValidationHash) {
      log('PIN authentication failed.');
      return false;
    }

    masterKeyHex = derivedKey;
    isLocked = false;
    onValidated
        ?.call(); // PIN confirmed — caller starts the unlock animation now

    await _finishUnlock();
    return true;
  }

  /// Biometric idle window: after this long without an unlock, the PIN is forced
  /// again even if fingerprint unlock is enabled.
  static const int _biometricMaxIdleMs = 4 * 60 * 60 * 1000; // 4 hours

  /// Whether a fingerprint unlock may be offered right now: the user opted in AND
  /// the last unlock was within the idle window. Safe to call before unlocking
  /// (the flag + timestamp are loaded in [AppState._initAndLoad]).
  bool biometricAllowedNow() {
    if (!biometricUnlockEnabled) return false;
    final last = lastUnlockMs;
    if (last == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - last;
    return age >= 0 && age < _biometricMaxIdleMs;
  }

  /// Unlock with the OS biometric instead of the PIN. Releases the Keystore-stashed
  /// master key on a confirmed match. Returns false (fall back to PIN) when not
  /// allowed, no key is stored, or the prompt is cancelled/failed.
  Future<bool> unlockWithBiometrics({VoidCallback? onValidated}) async {
    if (!biometricAllowedNow()) return false;
    final storedKey = await BiometricAuth.readMasterKey();
    if (storedKey == null) return false;
    final ok = await BiometricAuth.authenticate('Unlock Wiltkey');
    if (!ok) return false;

    masterKeyHex = storedKey;
    isLocked = false;
    onValidated?.call();
    await _finishUnlock();
    return true;
  }

  /// Opt into fingerprint unlock (called from settings while unlocked): confirm
  /// with a biometric prompt, then stash the current master key. Returns false if
  /// unavailable or the prompt is declined.
  Future<bool> enableBiometricUnlock() async {
    if (masterKeyHex == null) return false;
    if (!await BiometricAuth.isAvailable()) return false;
    final ok = await BiometricAuth.authenticate(
      'Confirm to enable fingerprint unlock',
    );
    if (!ok) return false;
    await BiometricAuth.storeMasterKey(masterKeyHex!);
    biometricUnlockEnabled = true;
    await _persistence.setBiometricEnabled(true);
    await _touchUnlock(); // start the 4h window from opt-in
    notifyListeners();
    return true;
  }

  /// Turn fingerprint unlock off and wipe the stashed master key.
  Future<void> disableBiometricUnlock() async {
    biometricUnlockEnabled = false;
    await BiometricAuth.clearMasterKey();
    await _persistence.setBiometricEnabled(false);
    notifyListeners();
  }

  /// Record the moment of a successful unlock so the biometric idle window resets.
  Future<void> _touchUnlock() async {
    lastUnlockMs = DateTime.now().millisecondsSinceEpoch;
    await _persistence.setLastUnlockMs(lastUnlockMs!);
  }

  /// The shared post-validation load, run by both the PIN and biometric unlock
  /// paths once [masterKeyHex] is set.
  Future<void> _finishUnlock() async {
    final fullData = await _persistence.loadState(masterKeyHex: masterKeyHex);

    if (fullData['publicKey'] != null && fullData['privateKey'] != null) {
      publicKeyHex = fullData['publicKey']!;
      privateKeyHex = fullData['privateKey']!;
      _identityKeyPair = ed25519.KeyPair(
        ed25519.PrivateKey(_hexToBytes(privateKeyHex)),
        ed25519.PublicKey(_hexToBytes(publicKeyHex)),
      );
      final sha256Digest = sha256.convert(_identityKeyPair.publicKey.bytes);
      userId = sha256Digest.toString();
    }

    deviceName = fullData['deviceName'] ?? '';
    shortNick = fullData['shortNick'] ?? '';
    profileImageB64 = fullData['profileImageB64'] ?? '';

    if (fullData['useLocalDevRelay'] != null) {
      useLocalDevRelay = fullData['useLocalDevRelay']!;
    }
    if (fullData['localDevRelayUrl'] != null) {
      localDevRelayUrl = fullData['localDevRelayUrl']!;
    }
    if (fullData['showDebugButtons'] != null) {
      showDebugButtons = fullData['showDebugButtons']!;
    }
    if (fullData['chatTextScale'] != null) {
      chatTextScale = (fullData['chatTextScale'] as double).clamp(0.8, 1.6);
    }
    if (fullData['knownPeerRelays'] != null) {
      knownPeerRelays = (fullData['knownPeerRelays'] as List)
          .cast<String>()
          .toSet();
    }
    if (fullData['lastReadMs'] != null) {
      try {
        final decoded =
            jsonDecode(fullData['lastReadMs'] as String)
                as Map<String, dynamic>;
        lastReadMs = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }

    // Initialize WiltkeyDatabase
    await WiltkeyDatabase.instance.init();
    contacts = await WiltkeyDatabase.instance.getAllContacts();
    // Messages are loaded lazily per-chat (newest page on open, older on
    // scroll-back) — see loadInitialMessages/loadOlderMessages. Unlock stays fast
    // and memory stays bounded regardless of total history. We only precompute
    // the unread counts the chats list needs.
    messages = {};
    unreadCounts = await WiltkeyDatabase.instance.getUnreadCounts(lastReadMs, [
      for (final c in contacts) c.id,
    ]);

    // Refund any send that failed in a previous session and was never retried —
    // rolls its keystream back and removes the dead "undelivered" bubble.
    await autoRefundAbandonedFailures();

    // Reclaim disk: delete any pad with no live (non-archived) contact. This
    // self-heals the cases where a pad can outlive its chat — incomplete/failed
    // pairings, a peer nuke that arrived while we were offline, or a crashed
    // recharge. Archived chats have no pad, so they're simply absent from keep.
    try {
      final keepIds = <String>{
        for (final c in contacts)
          if (!c.isArchived) (c.isGroup ? 'group_${c.keyHash}' : c.keyHash),
      };
      final wiped = await WiltkeyOtpService.reconcilePads(keepIds);
      if (wiped.isNotEmpty) {
        log('[Reconcile] Removed ${wiped.length} orphan pad(s): $wiped');
      }
    } catch (e) {
      log('[Reconcile] Pad reconciliation failed: $e');
    }

    // Refresh the keystore signing key / relay coordinates so locked-state
    // background workers can authenticate (also migrates existing users who
    // onboarded before the notification feature existed).
    await cacheBackgroundCredentials();

    notifyListeners();
    WebSocketClient().connect(activeRelayUrl, publicKeyHex: publicKeyHex);
    startConnectionWatchdog();

    // Decrypt + store anything the background socket buffered while we were
    // locked, then re-run the normal inbound path for it.
    await processPendingInbox();

    // Stamp the unlock so the biometric 4h idle window resets.
    await _touchUnlock();

    log('App unlocked. WebSocket connected.');
  }

  Future<void> setupPinAndInitialize({
    required String pin,
    required String username,
    required String codename,
    required String profileImage,
  }) async {
    final rand = Random.secure();
    final saltBytes = List<int>.generate(16, (i) => rand.nextInt(256));
    final pinSalt = saltBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    final derivedKey = deriveKey(pin, pinSalt);
    final pinValidationHash = sha256
        .convert(utf8.encode(derivedKey))
        .toString();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(WiltkeyPersistence.keyPinSalt, pinSalt);
    await prefs.setString(
      WiltkeyPersistence.keyPinValidationHash,
      pinValidationHash,
    );

    masterKeyHex = derivedKey;

    _generateIdentityKeypair();

    deviceName = username;
    shortNick = codename;
    profileImageB64 = profileImage;

    await WiltkeyDatabase.instance.init();
    await WiltkeyDatabase.instance.deleteAll(); // Clean start
    await _persistence.saveState(this, masterKeyHex: masterKeyHex);

    // Provision the keystore signing key for background notifications.
    await cacheBackgroundCredentials();

    isOnboardingRequired = false;
    isLocked = false;
    await _touchUnlock(); // start the biometric idle window from onboarding
    notifyListeners();
    WebSocketClient().connect(activeRelayUrl, publicKeyHex: publicKeyHex);
    startConnectionWatchdog();
    log('Onboarding complete. Enclave initialized.');
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    if (masterKeyHex == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final pinSalt = prefs.getString(WiltkeyPersistence.keyPinSalt);
    if (pinSalt == null) return false;

    final oldDerivedKey = deriveKey(oldPin, pinSalt);
    if (oldDerivedKey != masterKeyHex) return false;

    final rand = Random.secure();
    final saltBytes = List<int>.generate(16, (i) => rand.nextInt(256));
    final newPinSalt = saltBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    final newDerivedKey = deriveKey(newPin, newPinSalt);
    final newPinValidationHash = sha256
        .convert(utf8.encode(newDerivedKey))
        .toString();

    await prefs.setString(WiltkeyPersistence.keyPinSalt, newPinSalt);
    await prefs.setString(
      WiltkeyPersistence.keyPinValidationHash,
      newPinValidationHash,
    );

    masterKeyHex = newDerivedKey;
    await _persistence.saveState(this, masterKeyHex: masterKeyHex);

    // The master key is PIN-derived, so re-stash it for biometric unlock —
    // otherwise the old key would unlock to undecryptable data.
    if (biometricUnlockEnabled) {
      await BiometricAuth.storeMasterKey(newDerivedKey);
    }

    log('PIN changed successfully.');
    notifyListeners();
    return true;
  }

  void lockApp() {
    if (!isOnboardingRequired && masterKeyHex != null) {
      masterKeyHex = null;
      isLocked = true;
      stopConnectionWatchdog();
      _loadCleanState();
      WebSocketClient().disconnect();
      notifyListeners();
      log('[State] App locked due to minimize.');
    }
  }

  void resetApp() {
    _persistence.clearAll();
    WiltkeyDatabase.instance.deleteDbFile();
    _loadCleanState();
    masterKeyHex = null;
    isOnboardingRequired = true;
    isLocked = false;
    status = AppStatus.normal;
    log('[State] App reset and purged.');
    notifyListeners();
  }
}
