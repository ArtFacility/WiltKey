import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'models.dart';
import 'state.dart';
import 'auth/biometric_auth.dart';
import 'notifications/notification_service.dart';

class WiltkeyPersistence {
  static const String _keyPublicKey = 'wk_public_key';
  static const String _keyPrivateKey = 'wk_private_key';
  static const String _keyDeviceName = 'wk_device_name';
  static const String _keyShortNick = 'wk_short_nick';
  static const String _keyProfileImage = 'wk_profile_image';
  static const String _keyUseLocalDevRelay = 'wk_use_local_dev_relay';
  static const String _keyLocalDevRelayUrl = 'wk_local_dev_relay_url';
  static const String _keyShowDebugButtons = 'wk_show_debug_buttons';
  static const String _keyChatTextScale = 'wk_chat_text_scale';
  static const String _keyKnownPeerRelays = 'wk_known_relays';
  static const String _keyLastRead = 'wk_last_read';
  static const String _keyThemeId = 'wk_theme_id';
  static const String _keyNotificationMode = kPrefNotificationMode;
  static const String _keyLocale = 'wk_locale';

  // PIN security keys
  static const String keyPinSalt = 'wk_pin_salt';
  static const String keyPinValidationHash = 'wk_pin_validation_hash';

  // Optional biometric unlock: whether the user opted in, and the last time the
  // app was unlocked (used to force the PIN again after a 4h idle window).
  static const String _keyBiometricEnabled = 'wk_biometric_enabled';
  static const String _keyLastUnlockMs = 'wk_last_unlock_ms';

  Future<File> _getHistoryFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/wiltkey_history.json');
  }

  // Encrypt helper using AES-256-CBC with random IV prefix
  String encryptString(String plaintext, String keyHex) {
    final key = enc.Key.fromBase16(keyHex);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  // Decrypt helper using AES-256-CBC
  String decryptString(String encryptedWithIv, String keyHex) {
    final parts = encryptedWithIv.split(':');
    if (parts.length != 2) throw Exception('Invalid encrypted format');
    final key = enc.Key.fromBase16(keyHex);
    final iv = enc.IV.fromBase64(parts[0]);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt(enc.Encrypted.fromBase64(parts[1]), iv: iv);
  }

  Future<Map<String, dynamic>> loadState({String? masterKeyHex}) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> stateData = {};

    stateData['publicKey'] = prefs.getString(_keyPublicKey);
    stateData['deviceName'] = prefs.getString(_keyDeviceName) ?? '';
    stateData['shortNick'] = prefs.getString(_keyShortNick) ?? '';
    stateData['profileImageB64'] = prefs.getString(_keyProfileImage) ?? '';
    stateData['useLocalDevRelay'] = prefs.getBool(_keyUseLocalDevRelay);
    stateData['localDevRelayUrl'] = prefs.getString(_keyLocalDevRelayUrl);
    stateData['showDebugButtons'] = prefs.getBool(_keyShowDebugButtons);
    stateData['chatTextScale'] = prefs.getDouble(_keyChatTextScale);
    stateData['knownPeerRelays'] = prefs.getStringList(_keyKnownPeerRelays);
    stateData['lastReadMs'] = prefs.getString(_keyLastRead);
    stateData['pinSalt'] = prefs.getString(keyPinSalt);
    stateData['pinValidationHash'] = prefs.getString(keyPinValidationHash);
    stateData['notificationMode'] = prefs.getString(_keyNotificationMode);
    stateData['biometricEnabled'] =
        prefs.getBool(_keyBiometricEnabled) ?? false;
    stateData['lastUnlockMs'] = prefs.getInt(_keyLastUnlockMs);

    final privateKeyRaw = prefs.getString(_keyPrivateKey);
    if (privateKeyRaw != null) {
      if (masterKeyHex != null) {
        try {
          stateData['privateKey'] = decryptString(privateKeyRaw, masterKeyHex);
        } catch (e) {
          print('[Persistence Error] Failed to decrypt private key: $e');
        }
      } else {
        stateData['hasEncryptedPrivateKey'] = true;
      }
    }

    return stateData;
  }

  Future<void> saveState(AppState state, {String? masterKeyHex}) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyPublicKey, state.publicKeyHex);
    await prefs.setString(_keyDeviceName, state.deviceName);
    await prefs.setString(_keyShortNick, state.shortNick);
    await prefs.setString(_keyProfileImage, state.profileImageB64);
    await prefs.setBool(_keyUseLocalDevRelay, state.useLocalDevRelay);
    await prefs.setBool(_keyShowDebugButtons, state.showDebugButtons);
    await prefs.setDouble(_keyChatTextScale, state.chatTextScale);
    await prefs.setStringList(
      _keyKnownPeerRelays,
      state.knownPeerRelays.toList(),
    );
    await prefs.setString(_keyLastRead, jsonEncode(state.lastReadMs));
    await prefs.setString(_keyLocalDevRelayUrl, state.localDevRelayUrl);
    await prefs.setString(
      _keyNotificationMode,
      state.notificationMode.storageValue,
    );

    // Save encrypted private key if masterKeyHex is provided
    final mKey = masterKeyHex ?? state.masterKeyHex;
    if (mKey != null) {
      final encryptedPrivate = encryptString(state.privateKeyHex, mKey);
      await prefs.setString(_keyPrivateKey, encryptedPrivate);
    }
  }

  // --- Pairing-time ledger (stale-nuke guard) ---
  // A small {keyHash: epochMs} map recording when each contact was last paired
  // or recharged. Used to reject a stale `nuke` that lingered on the relay (7-day
  // TTL) and arrives AFTER the two devices re-paired — without it, that ghost
  // nuke wipes the freshly-made contact on one side only. Kept out of the DB so
  // it survives independently of contact rows (an undelivered nuke can target a
  // keyHash that has no local contact row yet).
  static const String _keyPairingTimes = 'wk_pairing_times';

  Future<Map<String, dynamic>> _loadPairingTimes(SharedPreferences prefs) async {
    final raw = prefs.getString(_keyPairingTimes);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  Future<void> setPairingTime(String keyHash, int epochMs) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _loadPairingTimes(prefs);
    map[keyHash] = epochMs;
    await prefs.setString(_keyPairingTimes, jsonEncode(map));
  }

  Future<int?> getPairingTime(String keyHash) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _loadPairingTimes(prefs);
    final v = map[keyHash];
    return v is int ? v : (v is num ? v.toInt() : null);
  }

  Future<void> clearPairingTime(String keyHash) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _loadPairingTimes(prefs);
    if (map.remove(keyHash) != null) {
      await prefs.setString(_keyPairingTimes, jsonEncode(map));
    }
  }

  // --- Optional biometric unlock ---
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
  }

  Future<void> setLastUnlockMs(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastUnlockMs, ms);
  }

  // --- Theme selection (cosmetic) ---
  // Stored separately from identity/keys and intentionally NOT wiped by
  // clearAll(): a theme id reveals nothing sensitive, and a user's chosen look
  // should survive a self-destruct/reset. Do not move into the wipe list.
  Future<String?> loadThemeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeId);
  }

  Future<void> saveThemeId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeId, id);
  }

  Future<String?> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocale);
  }

  Future<void> saveLocale(String localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, localeCode);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPublicKey);
    await prefs.remove(_keyPrivateKey);
    await prefs.remove(_keyDeviceName);
    await prefs.remove(_keyShortNick);
    await prefs.remove(_keyProfileImage);
    await prefs.remove(_keyUseLocalDevRelay);
    await prefs.remove(_keyLocalDevRelayUrl);
    await prefs.remove(_keyShowDebugButtons);
    await prefs.remove(_keyChatTextScale);
    await prefs.remove(_keyKnownPeerRelays);
    await prefs.remove(_keyLastRead);
    await prefs.remove(keyPinSalt);
    await prefs.remove(keyPinValidationHash);
    await prefs.remove(_keyBiometricEnabled);
    await prefs.remove(_keyLastUnlockMs);
    await prefs.remove(_keyPairingTimes);

    // Tear down background notification work and wipe the keystore signing key.
    await WiltkeyNotifications.clearCredentials();
    // Wipe the biometric-stashed master key so a reset/nuke leaves nothing behind.
    await BiometricAuth.clearMasterKey();

    try {
      final file = await _getHistoryFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('[Persistence Error] Failed to delete history file: $e');
    }
  }
}
