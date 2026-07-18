// Flavor-agnostic value types exchanged with the native `wiltkey/billing`
// bridge. These carry no Google types, so they compile into every flavor; only
// the native bridge (src/play/) and the Play Billing library are Play-only.

/// A purchasable item as reported by Google Play Billing, with the localized,
/// currency-correct price string Play hands us (never hardcode prices).
class BillingProduct {
  /// The Play product id (see [WkProducts]).
  final String id;

  /// Localized product title from the Play Console listing.
  final String title;

  /// Localized product description from the Play Console listing.
  final String description;

  /// Localized, currency-formatted price, e.g. "$1.99" / "1,99 €".
  final String formattedPrice;

  /// True for the subscription ([WkProducts.plusSubscription]); false for the
  /// one-time managed products.
  final bool isSubscription;

  const BillingProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.formattedPrice,
    required this.isSubscription,
  });

  factory BillingProduct.fromMap(Map<dynamic, dynamic> map) => BillingProduct(
        id: (map['id'] as String?) ?? '',
        title: (map['title'] as String?) ?? '',
        description: (map['description'] as String?) ?? '',
        formattedPrice: (map['price'] as String?) ?? '',
        isSubscription: (map['isSubscription'] as bool?) ?? false,
      );
}

/// Outcome of a [BillingChannel.buy] flow (or a restore), mirrored from the
/// native BillingClient response codes into a small, stable enum.
enum PurchaseOutcome {
  /// Purchase completed and is owned (acknowledged native-side).
  purchased,

  /// Payment is pending (e.g. slow card / cash) — not yet owned.
  pending,

  /// User dismissed the Play sheet.
  cancelled,

  /// Already owned (treated as success by callers).
  alreadyOwned,

  /// Billing unavailable (FOSS build, no Play Services, or a client error).
  unavailable,

  /// Any other BillingClient error.
  error,
}

/// Result of a purchase attempt, including which product it concerned.
class PurchaseResult {
  final PurchaseOutcome outcome;
  final String? productId;

  /// Optional human-readable detail for logging / debug surfaces.
  final String? message;

  const PurchaseResult(this.outcome, {this.productId, this.message});

  bool get isSuccess =>
      outcome == PurchaseOutcome.purchased ||
      outcome == PurchaseOutcome.alreadyOwned;

  factory PurchaseResult.fromMap(Map<dynamic, dynamic> map) {
    final code = (map['outcome'] as String?) ?? 'error';
    final outcome = PurchaseOutcome.values.firstWhere(
      (o) => o.name == code,
      orElse: () => PurchaseOutcome.error,
    );
    return PurchaseResult(
      outcome,
      productId: map['productId'] as String?,
      message: map['message'] as String?,
    );
  }
}
