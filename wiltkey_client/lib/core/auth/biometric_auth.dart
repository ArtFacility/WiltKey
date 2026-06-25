import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Optional fingerprint/biometric unlock.
///
/// When enabled, the PIN-derived master key is stashed in the Android
/// Keystore-backed secure store and released after an OS biometric prompt, so
/// casual users can skip typing the PIN. The PIN is still required after the 4h
/// idle window (enforced by AppState.biometricAllowedNow) and on every fresh
/// device boot the OS may invalidate biometrics. The biometric prompt is the
/// access gate; the key itself is Keystore-encrypted at rest.
class BiometricAuth {
  static const String _kMasterKey = 'wk_bio_master_key';
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Whether the device has biometrics enrolled and usable.
  static Future<bool> isAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      return await _localAuth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Show the OS biometric prompt. Returns true only on a confirmed match.
  static Future<bool> authenticate(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  static Future<void> storeMasterKey(String hex) =>
      _secure.write(key: _kMasterKey, value: hex);

  static Future<String?> readMasterKey() => _secure.read(key: _kMasterKey);

  static Future<void> clearMasterKey() => _secure.delete(key: _kMasterKey);
}
