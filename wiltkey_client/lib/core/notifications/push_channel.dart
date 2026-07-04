import 'package:flutter/services.dart';

import '../build_flavor.dart';

/// Thin Dart side of the Play-flavor FCM bridge.
///
/// The native counterpart lives under `android/app/src/play/` and is only
/// compiled into the Play build. On the FOSS build there's no native handler, so
/// [kFcmEnabled] is false and every call here short-circuits to a null/no-op —
/// nothing is ever sent to the platform channel. Even on Play, any channel error
/// (e.g. the handler not registered yet) is swallowed and treated as "no FCM",
/// so callers never have to guard.
class PushChannel {
  PushChannel._();

  static const MethodChannel _channel = MethodChannel('wiltkey/push');

  /// The device's current FCM registration token, or null if unavailable
  /// (FOSS build, Play Services missing, or the user denied notifications).
  static Future<String?> getToken() async {
    if (!kFcmEnabled) return null;
    try {
      final token = await _channel.invokeMethod<String>('getToken');
      return (token != null && token.isNotEmpty) ? token : null;
    } catch (_) {
      return null;
    }
  }

  /// Delete the device's FCM token locally (Firebase side). Called when the user
  /// leaves Instant mode or nukes, so the device stops being wakeable by FCM even
  /// before the relay drops the token.
  static Future<void> deleteToken() async {
    if (!kFcmEnabled) return;
    try {
      await _channel.invokeMethod('deleteToken');
    } catch (_) {}
  }

  /// The chat keyHash a tapped FCM notification wants opened (and clears it), or
  /// null. Mirrors [WiltkeyNotifications.takePendingChat] for the native-posted
  /// Play-flavor notification, which flutter_local_notifications never sees.
  static Future<String?> takePendingChat() async {
    if (!kFcmEnabled) return null;
    try {
      final key = await _channel.invokeMethod<String>('takePendingChat');
      return (key != null && key.isNotEmpty) ? key : null;
    } catch (_) {
      return null;
    }
  }
}
