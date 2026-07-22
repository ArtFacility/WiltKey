import 'package:flutter/material.dart';

import '../build_flavor.dart';
import '../persistence.dart';
import 'billing_channel.dart';
import 'billing_models.dart';
import 'product_ids.dart';

/// Single source of truth for what the user has unlocked.
///
/// A [ChangeNotifier] singleton (matching the app's `ThemeController` /
/// `LocaleController` idiom — no Provider/Riverpod). The UI reads the boolean
/// getters and rebuilds when [notifyListeners] fires.
///
/// **Flavor split (runtime, mirrors the FCM push gate):**
/// - **Play build** (`kPlayStore` true): entitlements come from Google Play
///   Billing via [BillingChannel]. Owned managed products + active subscription
///   are queried on launch/resume, cached to prefs for offline launches.
/// - **FOSS build** (`kPlayStore` false): no billing library is compiled in, so
///   the fairness model is applied purely in code — palette packs and larger pads
///   are **free**, premium themes are **not available** (their source isn't in the
///   public repo and they're never listed), and Plus (server perks) is **off**
///   (the official relay requires payment; a self-hoster sets their own TTL).
///
/// **Trust model:** for purely-local cosmetics the client entitlement is accepted
/// (a pirate only cheats their own device, never a peer — rendering is always
/// free). The one perk that spends the operator's resources, the offline message
/// hold, is re-verified server-side and is NOT trusted from here.
class EntitlementService extends ChangeNotifier {
  static final EntitlementService _instance = EntitlementService._internal();
  factory EntitlementService() => _instance;
  EntitlementService._internal();

  static EntitlementService get instance => _instance;

  final WiltkeyPersistence _persistence = WiltkeyPersistence();

  /// Owned Play product ids (managed products + active subscriptions). On FOSS
  /// this stays empty and the getters below apply the free-tier rules directly.
  Set<String> _owned = <String>{};

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Whether purchasing is even possible in this build (official Play build).
  /// The Shop uses this to switch between a product list and the FOSS
  /// "Support the project" page.
  bool get billingAvailable => kPlayStore;

  // --- Entitlement getters (what the UI checks) ---

  /// Raw ownership check against the owned product-id set (Play only).
  bool ownsProduct(String productId) => _owned.contains(productId);

  /// The "WiltKey Plus" subscription — drives the 72h offline hold and future
  /// capacity perks. Always false on FOSS (server perks require the paid relay).
  /// Advisory locally; the relay re-verifies before granting the longer hold.
  bool get plusActive =>
      kPlayStore && _owned.contains(WkProducts.plusSubscription);

  /// Larger OTP pad size at pairing and larger group pads. Free on FOSS ("just
  /// an adjustment"); part of the **Plus subscription** on Play.
  ///
  /// Note a pad, once allocated, is permanent local key material — a lapsed
  /// subscriber keeps every pad they already paired. This only gates creating
  /// new large ones.
  bool get largerPadsUnlocked => !kPlayStore || plusActive;

  /// A palette pack for pixel-art authoring. Free on FOSS; owned check on Play.
  /// (Rendering pixel art with any palette is always free for everyone — only
  /// *authoring* with a pack is gated; see the palette-rework rule.)
  bool palettePackUnlocked(String packId) =>
      !kPlayStore || _owned.contains(WkProducts.palettePack(packId));

  /// A premium theme. NOT available on FOSS (never listed there); an owned check
  /// on Play. Note a theme always *renders* — this only gates selecting it.
  bool premiumThemeUnlocked(String themeId) =>
      kPlayStore && _owned.contains(WkProducts.premiumTheme(themeId));

  /// A premium avatar border. Owned check on Play; NOT available on FOSS (the
  /// only FOSS border is the free one, which never routes through here). A
  /// border always *renders* for everyone (it's broadcast art); this gates only
  /// whether the local user may equip it.
  bool premiumBorderUnlocked(String borderId) =>
      kPlayStore && _owned.contains(WkProducts.avatarBorder(borderId));

  // --- Lifecycle ---

  /// Reads the cached entitlements (instant, offline) then, on Play, refreshes
  /// from Billing in the background. Call once in `main()`. Cheap and safe on
  /// FOSS (no Google touchpoint).
  Future<void> load() async {
    if (kPlayStore) {
      final cached = await _persistence.loadEntitlements();
      _owned = cached.toSet();
      BillingChannel.onPurchasesChanged = _onPurchasesChanged;
      BillingChannel.ensureInitialized();
    }
    _loaded = true;
    notifyListeners();
    // Best-effort live refresh; failures leave the cached set in place.
    if (kPlayStore) {
      // ignore: unawaited_futures
      refresh();
    }
  }

  /// Re-queries owned products from Play Billing and updates state if changed.
  /// No-op on FOSS.
  Future<void> refresh() async {
    if (!kPlayStore) return;
    final owned = await BillingChannel.queryOwnedProducts();
    await _apply(owned);
  }

  /// Fetches localized product details for the Shop. Empty on FOSS.
  Future<List<BillingProduct>> productDetails(List<String> ids) =>
      BillingChannel.queryProducts(ids);

  /// Launches the Play purchase flow. Refreshes owned state on success. On FOSS
  /// returns [PurchaseOutcome.unavailable].
  Future<PurchaseResult> buy(
    String productId, {
    required bool subscription,
  }) async {
    if (!kPlayStore) {
      return const PurchaseResult(PurchaseOutcome.unavailable);
    }
    final result =
        await BillingChannel.buy(productId, subscription: subscription);
    if (result.isSuccess) {
      await refresh();
    }
    return result;
  }

  /// The active Plus subscription's Play purchase token, or null if not
  /// subscribed / FOSS. Used by the relay entitlement sync (server perks); the
  /// local cosmetic getters never need it.
  Future<String?> plusPurchaseToken() => BillingChannel.getPlusToken();

  /// Restores prior purchases (re-query for the signed-in Google account).
  /// No-op on FOSS.
  Future<void> restore() async {
    if (!kPlayStore) return;
    final owned = await BillingChannel.restore();
    await _apply(owned);
  }

  // --- internals ---

  void _onPurchasesChanged() {
    // Native pushed a change; re-query authoritatively.
    // ignore: unawaited_futures
    refresh();
  }

  bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  Future<void> _apply(Set<String> owned) async {
    if (_sameSet(owned, _owned)) return;
    _owned = owned;
    await _persistence.saveEntitlements(owned.toList());
    notifyListeners();
  }
}
