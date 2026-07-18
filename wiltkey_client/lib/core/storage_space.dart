import 'package:flutter/services.dart';

/// Free-space probe for OTP pad generation.
///
/// A 1:1 pad is a single `keystream_<id>.pad` file of exactly the agreed buffer
/// size (see `OtpService.generateKeystreamFile`), written to app-private internal
/// storage. Generating one on a device that can't fit it fails *mid-write*, after
/// the peer has already committed — leaving a half-made chat on one side only. So
/// both sides check before committing.
///
/// Backed by Android's `File.getUsableSpace()` via the `wiltkey/storage` channel
/// (declared in SecureFlutterActivity, so both flavors have it). That API needs
/// **no permission** and already accounts for reserved/quota space.
class WkStorageSpace {
  WkStorageSpace._();

  static const MethodChannel _channel = MethodChannel('wiltkey/storage');

  /// Breathing room kept free beyond the pad itself, so a pairing never fills the
  /// device to zero (the DB, message media and the OS all still need room).
  static const int headroomBytes = 32 * 1000 * 1000; // 32 MB

  /// Bytes this app can still write to internal storage, or null if the platform
  /// didn't answer (non-Android, or the channel isn't registered).
  static Future<int?> usableSpaceBytes() async {
    try {
      return await _channel.invokeMethod<int>('usableSpace');
    } catch (_) {
      return null;
    }
  }

  /// Total bytes a pad of [padBytes] needs to land safely, headroom included.
  static int requiredFor(int padBytes) => padBytes + headroomBytes;

  /// Whether a pad of [padBytes] fits. **Fails open**: if the platform can't tell
  /// us the free space, we allow the pairing rather than block a working device on
  /// a probe failure (the old, unchecked behaviour).
  static Future<bool> hasSpaceFor(int padBytes) async {
    final free = await usableSpaceBytes();
    if (free == null) return true;
    return free >= requiredFor(padBytes);
  }
}
