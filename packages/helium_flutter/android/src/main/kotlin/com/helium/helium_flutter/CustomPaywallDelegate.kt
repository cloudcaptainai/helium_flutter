package com.helium.helium_flutter

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.tryhelium.paywall.delegate.HeliumPaywallDelegate
import com.tryhelium.paywall.core.HeliumPaywallTransactionStatus
import kotlinx.coroutines.suspendCancellableCoroutine
import com.android.billingclient.api.ProductDetails
import kotlin.coroutines.resume

/**
 * Custom Helium Paywall Delegate that bridges purchase calls to Flutter.
 * Similar to DemoHeliumPaywallDelegate in iOS.
 */
class CustomPaywallDelegate(
  override val delegateType: String,
  private val methodChannel: MethodChannel
) : HeliumPaywallDelegate {

  private val mainHandler = Handler(Looper.getMainLooper())

  override suspend fun makePurchase(
    productDetails: ProductDetails,
    basePlanId: String?,
    offerId: String?
  ): HeliumPaywallTransactionStatus {
    return suspendCancellableCoroutine { continuation ->
      val arguments = mapOf(
        "productId" to productDetails.productId,
        "basePlanId" to basePlanId,
        "offerId" to offerId
      )

      // Must invoke on main thread - Flutter's MethodChannel requires it
      mainHandler.post {
        try {
          methodChannel.invokeMethod(
            "makePurchase",
            arguments,
            object : MethodChannel.Result {
              override fun success(result: Any?) {
                val status: HeliumPaywallTransactionStatus = when {
                  result is Map<*, *> -> {
                    val statusString = result["status"] as? String
                    val lowercasedStatus = statusString?.lowercase()

                    when (lowercasedStatus) {
                      "purchased" -> HeliumPaywallTransactionStatus.Purchased
                      "restored" -> HeliumPaywallTransactionStatus.Purchased
                      "cancelled" -> HeliumPaywallTransactionStatus.Cancelled
                      "pending" -> HeliumPaywallTransactionStatus.Pending
                      "failed" -> {
                        val errorMsg = result["error"] as? String ?: "Unknown purchase error"
                        HeliumPaywallTransactionStatus.Failed(Exception(errorMsg))
                      }
                      else -> {
                        HeliumPaywallTransactionStatus.Failed(
                          Exception("Unknown status: $lowercasedStatus")
                        )
                      }
                    }
                  }
                  else -> {
                    HeliumPaywallTransactionStatus.Failed(
                      Exception("Invalid response format")
                    )
                  }
                }

                continuation.resume(status)
              }

              override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                continuation.resume(
                  HeliumPaywallTransactionStatus.Failed(Exception(errorMessage ?: errorCode))
                )
              }

              override fun notImplemented() {
                continuation.resume(
                  HeliumPaywallTransactionStatus.Failed(Exception("Method not implemented"))
                )
              }
            }
          )
        } catch (e: Exception) {
          // Channel may be detached
          continuation.resume(
            HeliumPaywallTransactionStatus.Failed(Exception("Channel unavailable: ${e.message}"))
          )
        }
      }
    }
  }

  override suspend fun restorePurchases(): Boolean {
    return suspendCancellableCoroutine { continuation ->
      // Must invoke on main thread - Flutter's MethodChannel requires it
      mainHandler.post {
        try {
          methodChannel.invokeMethod(
            "restorePurchases",
            null,
            object : MethodChannel.Result {
              override fun success(result: Any?) {
                val success = (result as? Boolean) ?: false
                continuation.resume(success)
              }

              override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                continuation.resume(false)
              }

              override fun notImplemented() {
                continuation.resume(false)
              }
            }
          )
        } catch (e: Exception) {
          // Channel may be detached
          continuation.resume(false)
        }
      }
    }
  }
}
