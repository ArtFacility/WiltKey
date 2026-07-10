import 'package:flutter/services.dart';

/// Dart side of the native `wiltkey/security` channel (handler in
/// `SecureFlutterActivity`, shared by both flavors).
///
/// Everything here is fail-open, mirroring [PushChannel]: any channel error, a
/// non-Android platform, or a malformed reply is treated as "nothing to warn
/// about" so a security probe can never itself break the app.
class SecurityService {
  SecurityService._();

  static const MethodChannel _channel = MethodChannel('wiltkey/security');

  /// Whether a non-allowlisted accessibility service is currently enabled, plus
  /// the human-readable labels of the offending services (for the warning copy).
  ///
  /// This is an informational signal only — accessibility services are used by
  /// plenty of legitimate tools (password managers, clipboard managers, button
  /// remappers), so callers must present it as a soft heads-up, never a block.
  static Future<({bool unsafe, List<String> labels})> checkAccessibility() async {
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('checkUnsafeAccessibility');
      if (result == null) return (unsafe: false, labels: const <String>[]);
      final unsafe = result['unsafe'] == true;
      final labels = (result['labels'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const <String>[];
      return (unsafe: unsafe, labels: labels);
    } catch (_) {
      return (unsafe: false, labels: const <String>[]);
    }
  }

  /// Open the system accessibility settings so the user can review/disable the
  /// active service. No-op on error.
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }
}
