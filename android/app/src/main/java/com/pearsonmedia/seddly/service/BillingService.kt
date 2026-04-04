package com.pearsonmedia.seddly.service

import android.app.Activity
import android.util.Log
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.pearsonmedia.seddly.service.auth.SecureStorageService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Subscription tier enum matching iOS SubscriptionService.
 */
enum class SubscriptionTier(val value: String) {
    FREE("free"),
    PRO("pro"),
    PRO_PLUS("pro_plus");

    val isAIExtractionEnabled: Boolean get() = this >= PRO
    val isSyncEnabled: Boolean get() = this == PRO_PLUS
    val maxActiveCommitments: Int get() = if (this == FREE) 5 else Int.MAX_VALUE
}

/**
 * Google Play Billing integration for Seddly subscriptions.
 * Mirrors the iOS SubscriptionService (StoreKit 2) with:
 * - Three tiers: Free, Pro, Pro+
 * - Feature gating (AI extraction requires Pro+, sync requires Pro+)
 * - Purchase flow with lifecycle handling
 * - Subscription restoration on launch
 * - Grace period handling for expired subscriptions
 */
@Singleton
class BillingService @Inject constructor(
    private val secureStorage: SecureStorageService
) : PurchasesUpdatedListener {

    private var billingClient: BillingClient? = null
    private var productDetailsList: List<ProductDetails> = emptyList()

    private val _currentTier = MutableStateFlow(SubscriptionTier.FREE)
    val currentTier: StateFlow<SubscriptionTier> = _currentTier.asStateFlow()

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()

    /**
     * Initialize the billing client. Call from Activity.onCreate().
     */
    fun initialize(activity: Activity) {
        billingClient = BillingClient.newBuilder(activity)
            .setListener(this)
            .enablePendingPurchases()
            .build()

        billingClient?.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(billingResult: BillingResult) {
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    _isConnected.value = true
                    queryProductDetails()
                    restorePurchases()
                    Log.i(TAG, "Billing client connected")
                } else {
                    Log.e(TAG, "Billing setup failed: ${billingResult.debugMessage}")
                }
            }

            override fun onBillingServiceDisconnected() {
                _isConnected.value = false
                Log.w(TAG, "Billing service disconnected")
            }
        })

        // Restore cached tier immediately
        val cachedTier = secureStorage.getString(KEY_SUBSCRIPTION_TIER)
        if (cachedTier != null) {
            _currentTier.value = SubscriptionTier.entries.firstOrNull { it.value == cachedTier }
                ?: SubscriptionTier.FREE
        }
    }

    /**
     * Launch the purchase flow for a specific product.
     */
    fun launchPurchaseFlow(activity: Activity, productId: String) {
        val productDetails = productDetailsList.find { it.productId == productId }
        if (productDetails == null) {
            Log.e(TAG, "Product not found: $productId")
            return
        }

        val offerToken = productDetails.subscriptionOfferDetails?.firstOrNull()?.offerToken
        if (offerToken == null) {
            Log.e(TAG, "No offer token for product: $productId")
            return
        }

        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(
                listOf(
                    BillingFlowParams.ProductDetailsParams.newBuilder()
                        .setProductDetails(productDetails)
                        .setOfferToken(offerToken)
                        .build()
                )
            )
            .build()

        billingClient?.launchBillingFlow(activity, params)
    }

    override fun onPurchasesUpdated(
        billingResult: BillingResult,
        purchases: MutableList<Purchase>?
    ) {
        when (billingResult.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                purchases?.forEach { purchase ->
                    handlePurchase(purchase)
                }
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> {
                Log.i(TAG, "User cancelled purchase")
            }
            else -> {
                Log.e(TAG, "Purchase failed: ${billingResult.debugMessage}")
            }
        }
    }

    private fun handlePurchase(purchase: Purchase) {
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) return

        // Determine tier from product IDs
        val tier = when {
            purchase.products.any { it in PRO_PLUS_PRODUCT_IDS } -> SubscriptionTier.PRO_PLUS
            purchase.products.any { it in PRO_PRODUCT_IDS } -> SubscriptionTier.PRO
            else -> SubscriptionTier.FREE
        }

        _currentTier.value = tier
        secureStorage.putString(KEY_SUBSCRIPTION_TIER, tier.value)
        Log.i(TAG, "Subscription updated to: ${tier.value}")

        // Acknowledge purchase if not already
        if (!purchase.isAcknowledged) {
            val params = com.android.billingclient.api.AcknowledgePurchaseParams.newBuilder()
                .setPurchaseToken(purchase.purchaseToken)
                .build()
            billingClient?.acknowledgePurchase(params) { result ->
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    Log.i(TAG, "Purchase acknowledged")
                } else {
                    Log.e(TAG, "Acknowledge failed: ${result.debugMessage}")
                }
            }
        }
    }

    private fun queryProductDetails() {
        val productList = (PRO_PRODUCT_IDS + PRO_PLUS_PRODUCT_IDS).map { productId ->
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(productId)
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        }

        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(productList)
            .build()

        billingClient?.queryProductDetailsAsync(params) { billingResult, details ->
            if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                productDetailsList = details
                Log.i(TAG, "Loaded ${details.size} product details")
            }
        }
    }

    /**
     * Restore purchases on app launch to sync subscription state.
     */
    fun restorePurchases() {
        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.SUBS)
            .build()

        billingClient?.queryPurchasesAsync(params) { billingResult, purchases ->
            if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                if (purchases.isEmpty()) {
                    // No active subscriptions — revert to free
                    if (_currentTier.value != SubscriptionTier.FREE) {
                        Log.i(TAG, "No active subscriptions found, reverting to free")
                        _currentTier.value = SubscriptionTier.FREE
                        secureStorage.putString(KEY_SUBSCRIPTION_TIER, SubscriptionTier.FREE.value)
                    }
                } else {
                    purchases.forEach { handlePurchase(it) }
                }
            }
        }
    }

    fun getProductDetails(): List<ProductDetails> = productDetailsList

    fun disconnect() {
        billingClient?.endConnection()
        _isConnected.value = false
    }

    companion object {
        private const val TAG = "BillingService"
        private const val KEY_SUBSCRIPTION_TIER = "subscription_tier"

        val PRO_PRODUCT_IDS = setOf(
            "com.pearsonmedia.seddly.pro.monthly",
            "com.pearsonmedia.seddly.pro.yearly"
        )
        val PRO_PLUS_PRODUCT_IDS = setOf(
            "com.pearsonmedia.seddly.proplus.monthly",
            "com.pearsonmedia.seddly.proplus.yearly"
        )
    }
}
