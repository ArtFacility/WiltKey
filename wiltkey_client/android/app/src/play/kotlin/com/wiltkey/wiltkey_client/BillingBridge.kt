package com.wiltkey.wiltkey_client

import android.app.Activity
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Play-flavor Google Play Billing bridge. Lives in src/play/, so it (and the
 * `com.android.billingclient` library it uses — a `playImplementation` dependency)
 * are compiled into the Play build ONLY; the FOSS build never links any Google
 * Billing code and the Dart [BillingChannel] simply no-ops there.
 *
 * Exposes the `wiltkey/billing` MethodChannel the Dart `EntitlementService` calls:
 *   • queryPurchases / restore → owned product ids (managed + active subs)
 *   • queryProducts            → localized title/price details for the Shop
 *   • buy                      → launches the Play purchase flow
 * and pushes `onPurchasesChanged` back to Dart whenever the owned set may have
 * moved (a completed flow, or a purchase made outside the app).
 *
 * The only subscription is [SUB_PLUS]; every other id is a one-time managed product.
 */
class BillingBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : PurchasesUpdatedListener {

    companion object {
        const val CHANNEL = "wiltkey/billing"

        /** The single subscription product id (mirrors WkProducts.plusSubscription). */
        const val SUB_PLUS = "wk_plus"

        private fun isSubscription(productId: String) = productId == SUB_PLUS
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    private val billingClient: BillingClient = BillingClient.newBuilder(activity)
        .setListener(this)
        .enablePendingPurchases(
            PendingPurchasesParams.newBuilder().enableOneTimeProducts().build()
        )
        .build()

    // Product details from the last query, so a buy() can launch without re-fetching.
    private val productCache = HashMap<String, ProductDetails>()

    // The in-flight buy() awaiting the async PurchasesUpdatedListener callback.
    private var pendingBuy: MethodChannel.Result? = null
    private var pendingBuyId: String? = null

    init {
        channel.setMethodCallHandler { call, result -> onMethod(call, result) }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        try {
            billingClient.endConnection()
        } catch (_: Exception) {
        }
    }

    // --- MethodChannel dispatch ---

    private fun onMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "queryPurchases", "restore" -> queryPurchases(result)
            "plusToken" -> plusToken(result)
            "queryProducts" -> {
                @Suppress("UNCHECKED_CAST")
                val ids = (call.argument<List<String>>("ids")) ?: emptyList()
                queryProducts(ids, result)
            }
            "buy" -> {
                val id = call.argument<String>("id")
                val sub = call.argument<Boolean>("subscription") ?: false
                if (id.isNullOrEmpty()) {
                    result.success(errorMap(null, "missing id"))
                } else {
                    buy(id, sub, result)
                }
            }
            else -> result.notImplemented()
        }
    }

    // --- Connection ---

    private fun ensureConnected(onReady: (Boolean) -> Unit) {
        if (billingClient.isReady) {
            onReady(true)
            return
        }
        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(billingResult: BillingResult) {
                onReady(billingResult.responseCode == BillingClient.BillingResponseCode.OK)
            }

            override fun onBillingServiceDisconnected() {
                // Next call re-checks isReady and reconnects on demand.
            }
        })
    }

    // --- Queries ---

    private fun queryPurchases(result: MethodChannel.Result) {
        ensureConnected { ok ->
            if (!ok) {
                onMain { result.success(emptyList<String>()) }
                return@ensureConnected
            }
            val owned = LinkedHashSet<String>()
            val inappParams = QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.INAPP).build()
            billingClient.queryPurchasesAsync(inappParams) { _, inappList ->
                collectOwned(inappList, owned)
                val subsParams = QueryPurchasesParams.newBuilder()
                    .setProductType(BillingClient.ProductType.SUBS).build()
                billingClient.queryPurchasesAsync(subsParams) { _, subsList ->
                    collectOwned(subsList, owned)
                    onMain { result.success(owned.toList()) }
                }
            }
        }
    }

    /**
     * Returns the Play purchaseToken of the active [SUB_PLUS] subscription, or null
     * if the user has no active Plus sub. The token is what the relay needs to
     * (eventually) verify the subscription with Google and grant the server-side
     * perks (72h offline hold, >=5MB file transfers). Read-only — never launches a
     * flow. Acknowledges the purchase if Play hasn't recorded that yet.
     */
    private fun plusToken(result: MethodChannel.Result) {
        ensureConnected { ok ->
            if (!ok) {
                onMain { result.success(null) }
                return@ensureConnected
            }
            val subsParams = QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.SUBS).build()
            billingClient.queryPurchasesAsync(subsParams) { _, subsList ->
                var token: String? = null
                for (p in subsList) {
                    if (p.purchaseState == Purchase.PurchaseState.PURCHASED &&
                        p.products.contains(SUB_PLUS)
                    ) {
                        if (!p.isAcknowledged) acknowledge(p)
                        token = p.purchaseToken
                        break
                    }
                }
                onMain { result.success(token) }
            }
        }
    }

    private fun collectOwned(purchases: List<Purchase>, into: MutableSet<String>) {
        for (p in purchases) {
            if (p.purchaseState == Purchase.PurchaseState.PURCHASED) {
                into.addAll(p.products)
                if (!p.isAcknowledged) acknowledge(p)
            }
        }
    }

    private fun acknowledge(purchase: Purchase) {
        val params = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken).build()
        billingClient.acknowledgePurchase(params) { /* best-effort */ }
    }

    private fun queryProducts(ids: List<String>, result: MethodChannel.Result) {
        if (ids.isEmpty()) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }
        ensureConnected { ok ->
            if (!ok) {
                onMain { result.success(emptyList<Map<String, Any?>>()) }
                return@ensureConnected
            }
            val productList = ids.map { id ->
                QueryProductDetailsParams.Product.newBuilder()
                    .setProductId(id)
                    .setProductType(
                        if (isSubscription(id)) BillingClient.ProductType.SUBS
                        else BillingClient.ProductType.INAPP
                    )
                    .build()
            }
            val params = QueryProductDetailsParams.newBuilder()
                .setProductList(productList).build()
            billingClient.queryProductDetailsAsync(params) { _, details ->
                val out = ArrayList<Map<String, Any?>>()
                for (d in details) {
                    productCache[d.productId] = d
                    out.add(
                        mapOf(
                            "id" to d.productId,
                            "title" to d.title,
                            "description" to d.description,
                            "price" to priceOf(d),
                            "isSubscription" to
                                (d.productType == BillingClient.ProductType.SUBS),
                        )
                    )
                }
                onMain { result.success(out) }
            }
        }
    }

    private fun priceOf(d: ProductDetails): String {
        d.oneTimePurchaseOfferDetails?.let { return it.formattedPrice }
        val phase = d.subscriptionOfferDetails
            ?.firstOrNull()
            ?.pricingPhases
            ?.pricingPhaseList
            ?.firstOrNull()
        return phase?.formattedPrice ?: ""
    }

    // --- Purchase flow ---

    private fun buy(id: String, subscription: Boolean, result: MethodChannel.Result) {
        if (pendingBuy != null) {
            result.success(errorMap(id, "another purchase in progress"))
            return
        }
        ensureConnected { ok ->
            if (!ok) {
                onMain { result.success(unavailableMap(id)) }
                return@ensureConnected
            }
            val cached = productCache[id]
            if (cached != null) {
                launchFlow(cached, subscription, id, result)
                return@ensureConnected
            }
            val product = QueryProductDetailsParams.Product.newBuilder()
                .setProductId(id)
                .setProductType(
                    if (subscription) BillingClient.ProductType.SUBS
                    else BillingClient.ProductType.INAPP
                )
                .build()
            val params = QueryProductDetailsParams.newBuilder()
                .setProductList(listOf(product)).build()
            billingClient.queryProductDetailsAsync(params) { _, details ->
                val d = details.firstOrNull()
                if (d == null) {
                    onMain { result.success(unavailableMap(id)) }
                } else {
                    productCache[id] = d
                    launchFlow(d, subscription, id, result)
                }
            }
        }
    }

    private fun launchFlow(
        details: ProductDetails,
        subscription: Boolean,
        id: String,
        result: MethodChannel.Result,
    ) {
        val builder = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(details)
        if (subscription) {
            val offerToken =
                details.subscriptionOfferDetails?.firstOrNull()?.offerToken
            if (offerToken == null) {
                onMain { result.success(errorMap(id, "no subscription offer")) }
                return
            }
            builder.setOfferToken(offerToken)
        }
        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(builder.build()))
            .build()

        pendingBuy = result
        pendingBuyId = id
        onMain {
            val launch = billingClient.launchBillingFlow(activity, flowParams)
            if (launch.responseCode != BillingClient.BillingResponseCode.OK) {
                pendingBuy = null
                pendingBuyId = null
                result.success(errorMap(id, launch.debugMessage))
            }
        }
    }

    override fun onPurchasesUpdated(
        billingResult: BillingResult,
        purchases: MutableList<Purchase>?,
    ) {
        val pending = pendingBuy
        val pendingId = pendingBuyId
        pendingBuy = null
        pendingBuyId = null

        when (billingResult.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                var outcome = "error"
                purchases?.forEach { p ->
                    if (p.purchaseState == Purchase.PurchaseState.PURCHASED) {
                        if (!p.isAcknowledged) acknowledge(p)
                        if (pendingId == null || p.products.contains(pendingId)) {
                            outcome = "purchased"
                        }
                    } else if (p.purchaseState == Purchase.PurchaseState.PENDING) {
                        if (pendingId == null || p.products.contains(pendingId)) {
                            outcome = "pending"
                        }
                    }
                }
                pending?.let { r ->
                    onMain { r.success(outcomeMap(outcome, pendingId)) }
                }
                notifyChanged()
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> {
                pending?.let { r ->
                    onMain { r.success(outcomeMap("cancelled", pendingId)) }
                }
            }
            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> {
                pending?.let { r ->
                    onMain { r.success(outcomeMap("alreadyOwned", pendingId)) }
                }
                notifyChanged()
            }
            else -> {
                pending?.let { r ->
                    onMain { r.success(errorMap(pendingId, billingResult.debugMessage)) }
                }
            }
        }
    }

    private fun notifyChanged() {
        onMain { channel.invokeMethod("onPurchasesChanged", null) }
    }

    // --- helpers ---

    private fun outcomeMap(outcome: String, productId: String?): Map<String, Any?> =
        mapOf("outcome" to outcome, "productId" to productId)

    private fun errorMap(productId: String?, message: String?): Map<String, Any?> =
        mapOf("outcome" to "error", "productId" to productId, "message" to message)

    private fun unavailableMap(productId: String?): Map<String, Any?> =
        mapOf("outcome" to "unavailable", "productId" to productId)

    private fun onMain(block: () -> Unit) = activity.runOnUiThread(block)
}
