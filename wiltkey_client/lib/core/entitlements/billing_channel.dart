import 'package:flutter/services.dart';

import '../build_flavor.dart';
import 'billing_models.dart';

/// Thin Dart side of the Play-flavor Google Play Billing bridge.
///
/// The native counterpart (`BillingBridge.kt`) lives under `android/app/src/play/`
/// and is only compiled into the Play build; the Play Billing library is a
/// `playImplementation` dependency, so the FOSS APK never links any Google Billing
/// code. On FOSS, [available] is false and every call short-circuits to an
/// empty/no-op result — nothing ever reaches the platform channel. Even on Play,
/// any channel error (handler not registered yet, transient disconnect) is
/// swallowed and treated as "billing unavailable", so callers never guard.
///
/// This is the low-level transport only; [EntitlementService] owns the app-facing
/// state and caching.
class BillingChannel {
  BillingChannel._();

  static const MethodChannel _channel = MethodChannel('wiltkey/billing');

  /// Fired by the native BillingClient's PurchasesUpdatedListener whenever the
  /// owned set may have changed (a completed flow, a restore, an out-of-app
  /// purchase). Set by [EntitlementService] to trigger a refresh.
  static void Function()? onPurchasesChanged;

  static bool _handlerInstalled = false;

  /// True only when a real Play Billing backend is present (official Play build).
  static bool get available => kPlayStore;

  /// Installs the reverse method-call handler once, so native can push
  /// purchase-changed notifications up to Dart. Idempotent; no-op on FOSS.
  static void ensureInitialized() {
    if (!available || _handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPurchasesChanged') {
        onPurchasesChanged?.call();
      }
      return null;
    });
  }

  /// The set of product ids the user currently owns (managed products) or has an
  /// active subscription for. Empty on FOSS or on any error.
  static Future<Set<String>> queryOwnedProducts() async {
    if (!available) return <String>{};
    try {
      final owned =
          await _channel.invokeMethod<List<dynamic>>('queryPurchases');
      if (owned == null) return <String>{};
      return owned.map((e) => e.toString()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// The Play purchaseToken of the active Plus subscription, or null if the user
  /// has no active Plus sub (or on FOSS / any error). The relay needs this token
  /// to grant the server-side perks (72h hold, large files); see
  /// [AppStateEntitlement.syncPlusEntitlement].
  static Future<String?> getPlusToken() async {
    if (!available) return null;
    try {
      return await _channel.invokeMethod<String>('plusToken');
    } catch (_) {
      return null;
    }
  }

  /// Localized product details (title/price) for [productIds]. Empty on FOSS or
  /// on any error, so the Shop UI can simply show nothing purchasable.
  static Future<List<BillingProduct>> queryProducts(
    List<String> productIds,
  ) async {
    if (!available || productIds.isEmpty) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'queryProducts',
        {'ids': productIds},
      );
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((m) => BillingProduct.fromMap(m))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Launches the Play purchase flow for [productId] and returns the outcome.
  /// [subscription] must match the product type. No-op → [PurchaseOutcome.unavailable]
  /// on FOSS.
  static Future<PurchaseResult> buy(
    String productId, {
    required bool subscription,
  }) async {
    if (!available) {
      return const PurchaseResult(PurchaseOutcome.unavailable);
    }
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'buy',
        {'id': productId, 'subscription': subscription},
      );
      if (raw == null) {
        return PurchaseResult(PurchaseOutcome.error, productId: productId);
      }
      return PurchaseResult.fromMap(raw);
    } catch (_) {
      return PurchaseResult(PurchaseOutcome.error, productId: productId);
    }
  }

  /// Asks the native side to re-query owned purchases (Play's restore is just a
  /// fresh query — non-consumables/subs are re-reported for the signed-in Google
  /// account, so purchases survive a reinstall or app-data wipe). No-op on FOSS.
  static Future<Set<String>> restore() async {
    if (!available) return <String>{};
    try {
      final owned = await _channel.invokeMethod<List<dynamic>>('restore');
      if (owned == null) return <String>{};
      return owned.map((e) => e.toString()).toSet();
    } catch (_) {
      return <String>{};
    }
  }
}
