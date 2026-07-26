import 'entitlements/entitlement_service.dart';

/// Client-side outgoing payload ceilings, mirroring the relay's enforcement so a
/// message is rejected *instantly* with an honest error instead of being built,
/// sent, and bounced.
///
/// The relay (`wiltkey_server`) caps the **JSON envelope** it receives:
///   - `freeMaxPayload` (5 MB): an envelope ≥ this needs an active Plus sub.
///   - `plusMaxPayload` (50 MB): a hard ceiling for everyone.
///
/// The envelope is NOT the raw image. The send path base64-encodes twice — the
/// image bytes → `base64Data` (the value callers hold), then the OTP ciphertext →
/// base64 again as the envelope's `d` field (~4/3 of `base64Data`), plus a small
/// JSON frame. So "5 MB free / 50 MB premium" is the **message payload** that
/// travels + is stored, which is what costs the operator — the honest metric.
/// [projectedEnvelope] reproduces that size from a `base64Data` length so
/// [exceedsOutgoing] applies the relay's exact two gates locally.
class WkPayloadLimits {
  WkPayloadLimits._();

  /// Envelope size at/above which the relay requires a Plus subscription.
  static const int freeMaxPayload = 5 * 1024 * 1024; // 5 MB

  /// Absolute envelope ceiling the relay rejects for everyone.
  static const int plusMaxPayload = 50 * 1024 * 1024; // 50 MB

  /// Estimated relay envelope size for a message whose base64 body is
  /// [base64Len] bytes: the `d` field is base64(cipher) ≈ 4/3 of the body, plus a
  /// generous JSON-frame allowance (offset/version/mime/flags).
  static int projectedEnvelope(int base64Len) => ((base64Len + 2) ~/ 3) * 4 + 256;

  /// The largest envelope the local user may send right now.
  static int get maxOutgoingPayload =>
      EntitlementService.instance.plusActive ? plusMaxPayload : freeMaxPayload;

  /// True if a message whose base64 body is [base64Len] bytes would be refused by
  /// the relay for the current entitlement (matches the server's two gates).
  static bool exceedsOutgoing(int base64Len) {
    final env = projectedEnvelope(base64Len);
    if (env > plusMaxPayload) return true;
    if (env >= freeMaxPayload && !EntitlementService.instance.plusActive) {
      return true;
    }
    return false;
  }

  /// True when the local user is on the free tier and a body of [base64Len] bytes
  /// is blocked *only* because it needs Plus (i.e. it fits the 50 MB hard ceiling).
  /// Drives the "upgrade for larger files" upsell vs the plain "too big" error.
  static bool blockedByFreeTier(int base64Len) =>
      exceedsOutgoing(base64Len) &&
      projectedEnvelope(base64Len) <= plusMaxPayload;
}
