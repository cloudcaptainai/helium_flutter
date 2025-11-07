package com.helium.helium_flutter

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.tryhelium.paywall.core.Helium
import com.tryhelium.paywall.core.HeliumConfigStatus
import com.tryhelium.paywall.core.HeliumEnvironment
import com.tryhelium.paywall.core.HeliumFallbackConfig
import com.tryhelium.paywall.core.HeliumIdentityManager
import com.tryhelium.paywall.core.HeliumUserTraits
import com.tryhelium.paywall.core.HeliumUserTraitsArgument
import com.tryhelium.paywall.core.HeliumPaywallTransactionStatus
import com.tryhelium.paywall.delegate.HeliumPaywallDelegate
import com.tryhelium.paywall.delegate.PlayStorePaywallDelegate
import com.android.billingclient.api.ProductDetails

/** HeliumFlutterPlugin */
class HeliumFlutterPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private var activity: Activity? = null
  private var context: Context? = null
  private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null
  private val gson = Gson()

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    this.flutterPluginBinding = flutterPluginBinding
    this.context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "helium_flutter")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "initialize" -> {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
          result.error("BAD_ARGS", "Arguments not passed correctly", null)
          return
        }

        val apiKey = args["apiKey"] as? String ?: ""
        val customApiEndpoint = args["customAPIEndpoint"] as? String
        val customUserId = args["customUserId"] as? String
        val useDefaultDelegate = args["useDefaultDelegate"] as? Boolean ?: false

        @Suppress("UNCHECKED_CAST")
        val customUserTraitsMap = args["customUserTraits"] as? Map<String, Any?>
        val customUserTraits = convertToHeliumUserTraits(customUserTraitsMap)

        @Suppress("UNCHECKED_CAST")
        val paywallLoadingConfigMap = args["paywallLoadingConfig"] as? Map<String, Any?>
        val fallbackConfig = convertToHeliumFallbackConfig(paywallLoadingConfigMap)

        // Use production environment by default
        // TODO: Add environment parameter to Flutter API if needed
        val environment = HeliumEnvironment.SANDBOX

        // Initialize on a coroutine scope
        CoroutineScope(Dispatchers.Main).launch {
          try {
            val currentContext = context
            val currentActivity = activity

            if (currentContext == null) {
              result.error("NO_CONTEXT", "Context not available", null)
              return@launch
            }

            // Create delegate
            val delegate = if (useDefaultDelegate) {
              if (currentActivity != null) {
                PlayStorePaywallDelegate(currentActivity)
              } else {
                result.error("DELEGATE_ERROR", "Activity not available for PlayStorePaywallDelegate", null)
                return@launch
              }
            } else {
              CustomPaywallDelegate(channel)
            }

            Helium.initialize(
              context = currentContext,
              apiKey = apiKey,
              heliumPaywallDelegate = delegate,
              customUserId = customUserId,
              customApiEndpoint = customApiEndpoint,
              customUserTraits = customUserTraits,
              fallbackConfig = fallbackConfig,
              environment = environment
            )

            result.success("Initialization started!")
          } catch (e: Exception) {
            result.error("INIT_ERROR", "Failed to initialize: ${e.message}", null)
          }
        }
      }
      "getDownloadStatus" -> {
        val status = Helium.shared.downloadStatus.value
        val statusString = when (status) {
          is HeliumConfigStatus.NotYetDownloaded -> "NotYetDownloaded"
          is HeliumConfigStatus.Downloading -> "Downloading"
          is HeliumConfigStatus.DownloadFailure -> "DownloadFailure"
          is HeliumConfigStatus.DownloadSuccess -> "DownloadSuccess"
        }
        result.success(statusString)
      }
      "presentUpsell" -> {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
          result.error("BAD_ARGS", "Arguments not passed correctly", null)
          return
        }

        val trigger = args["trigger"] as? String ?: ""

        @Suppress("UNCHECKED_CAST")
        val customPaywallTraitsMap = args["customPaywallTraits"] as? Map<String, Any?>
        val customPaywallTraits = convertToHeliumUserTraits(customPaywallTraitsMap)

        val dontShowIfAlreadyEntitled = args["dontShowIfAlreadyEntitled"] as? Boolean ?: false

        Helium.presentUpsell(
          trigger = trigger,
          // TODO add support for these
//          customPaywallTraits = customPaywallTraits,
//          dontShowIfAlreadyEntitled = dontShowIfAlreadyEntitled
        )

        result.success("Upsell presented!")
      }
      "hideUpsell" -> {
        result.notImplemented()
      }
      "getHeliumUserId" -> {
        val userId = HeliumIdentityManager.shared.getUserId()
        result.success(userId)
      }
      "paywallsLoaded" -> {
        val isLoaded = Helium.shared.downloadStatus.value is HeliumConfigStatus.DownloadSuccess
        result.success(isLoaded)
      }
      "overrideUserId" -> {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
          result.error("BAD_ARGS", "Arguments not passed correctly", null)
          return
        }

        val newUserId = args["newUserId"] as? String ?: ""

        @Suppress("UNCHECKED_CAST")
        val traitsMap = args["traits"] as? Map<String, Any?>
        val traits = convertToHeliumUserTraits(traitsMap)

        HeliumIdentityManager.shared.setCustomUserId(newUserId)
        traits?.let {
          HeliumIdentityManager.shared.setCustomUserTraits(it)
        }

        result.success("User id is updated!")
      }
      "fallbackOpenEvent" -> {
        result.notImplemented()
      }
      "fallbackCloseEvent" -> {
        result.notImplemented()
      }
      "getPaywallInfo" -> {
        val trigger = call.arguments as? String ?: ""
        val paywallInfo = Helium.getPaywallInfo(trigger)

        if (paywallInfo == null) {
          result.success(mapOf(
            "errorMsg" to "Invalid trigger or paywalls not ready.",
            "templateName" to null,
            "shouldShow" to null
          ))
        } else {
          result.success(mapOf(
            "errorMsg" to null,
            "templateName" to paywallInfo.paywallTemplateName,
            "shouldShow" to paywallInfo.shouldShow
          ))
        }
      }
      "canPresentUpsell" -> {
        result.notImplemented()
      }
      "handleDeepLink" -> {
        val urlString = call.arguments as? String
        val handled = Helium.handleDeepLink(uri = urlString)
        result.success(handled)
      }
      "hasAnyActiveSubscription" -> {
        result.notImplemented()
      }
      "hasAnyEntitlement" -> {
        result.notImplemented()
      }
      "hasEntitlementForPaywall" -> {
        result.notImplemented()
      }
      "getExperimentInfoForTrigger" -> {
        val trigger = call.arguments as? String ?: ""
        val experimentInfo = Helium.getExperimentInfoForTrigger(trigger)

        if (experimentInfo == null) {
          result.success(null)
        } else {
          // Convert ExperimentInfo to Map using Gson
          try {
            val json = gson.toJson(experimentInfo)
            val type = object : TypeToken<Map<String, Any?>>() {}.type
            val map: Map<String, Any?> = gson.fromJson(json, type)
            result.success(map)
          } catch (e: Exception) {
            result.success(null)
          }
        }
      }
      "disableRestoreFailedDialog" -> {
        result.notImplemented()
      }
      "setCustomRestoreFailedStrings" -> {
        result.notImplemented()
      }
      "resetHelium" -> {
        Helium.resetHelium()
        result.success("Helium reset!")
      }
      "setLightDarkModeOverride" -> {
        result.notImplemented()
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    this.flutterPluginBinding = null
    this.context = null
  }

  // Helper functions for type conversion

  /**
   * Recursively converts special marker strings back to boolean values to restore
   * type information that was preserved when passing through platform channels.
   *
   * Flutter's platform channels convert booleans to integers (0/1), so we use
   * special marker strings to preserve the original intent. This helper converts:
   * - "__helium_flutter_bool_true__" -> true
   * - "__helium_flutter_bool_false__" -> false
   * - All other values remain unchanged
   */
  private fun convertMarkersToBooleans(input: Map<String, Any?>?): Map<String, Any?>? {
    if (input == null) return null
    return input.mapValues { (_, value) ->
      convertValueMarkersToBooleans(value)
    }
  }

  private fun convertValueMarkersToBooleans(value: Any?): Any? {
    return when (value) {
      "__helium_flutter_bool_true__" -> true
      "__helium_flutter_bool_false__" -> false
      is String -> value
      is Map<*, *> -> {
        @Suppress("UNCHECKED_CAST")
        convertMarkersToBooleans(value as? Map<String, Any?>)
      }
      is List<*> -> value.map { convertValueMarkersToBooleans(it) }
      else -> value
    }
  }

  private fun convertToHeliumUserTraits(input: Map<String, Any?>?): HeliumUserTraits? {
    if (input == null) return null
    val convertedInput = convertMarkersToBooleans(input) ?: return null
    val traits = convertedInput.mapValues { (_, value) ->
      convertToHeliumUserTraitsArgument(value)
    }.filterValues { it != null }.mapValues { it.value!! }
    return HeliumUserTraits(traits)
  }

  private fun convertToHeliumUserTraitsArgument(value: Any?): HeliumUserTraitsArgument? {
    return when (value) {
      is String -> HeliumUserTraitsArgument.StringParam(value)
      is Int -> HeliumUserTraitsArgument.IntParam(value)
      is Long -> HeliumUserTraitsArgument.LongParam(value)
      is Double -> HeliumUserTraitsArgument.DoubleParam(value.toString())
      is Boolean -> HeliumUserTraitsArgument.BooleanParam(value)
      is List<*> -> {
        val items = value.mapNotNull { convertToHeliumUserTraitsArgument(it) }
        HeliumUserTraitsArgument.Array(items)
      }
      is Map<*, *> -> {
        @Suppress("UNCHECKED_CAST")
        val properties = (value as? Map<String, Any?>)?.mapValues { (_, v) ->
          convertToHeliumUserTraitsArgument(v)
        }?.filterValues { it != null }?.mapValues { it.value!! } ?: emptyMap()
        HeliumUserTraitsArgument.Complex(properties)
      }
      else -> null
    }
  }

  private fun convertToHeliumFallbackConfig(input: Map<String, Any?>?): HeliumFallbackConfig? {
    if (input == null) return null

    val useLoadingState = input["useLoadingState"] as? Boolean ?: true
    val loadingBudget = (input["loadingBudget"] as? Number)?.toLong() ?: 2000L
    val fallbackBundleName = input["fallbackBundleName"] as? String

    // Parse perTriggerLoadingConfig if present
    var perTriggerLoadingConfig: Map<String, HeliumFallbackConfig>? = null
    val perTriggerDict = input["perTriggerLoadingConfig"] as? Map<*, *>
    if (perTriggerDict != null) {
      perTriggerLoadingConfig = perTriggerDict.mapNotNull { (key, value) ->
        if (key is String && value is Map<*, *>) {
          @Suppress("UNCHECKED_CAST")
          val config = value as? Map<String, Any?>
          val triggerUseLoadingState = config?.get("useLoadingState") as? Boolean
          val triggerLoadingBudget = (config?.get("loadingBudget") as? Number)?.toLong()
          key to HeliumFallbackConfig(
            useLoadingState = triggerUseLoadingState ?: true,
            loadingBudgetInMs = triggerLoadingBudget ?: 2000L
          )
        } else {
          null
        }
      }.toMap()
    }

    return HeliumFallbackConfig(
      useLoadingState = useLoadingState,
      loadingBudgetInMs = loadingBudget,
      perTriggerLoadingConfig = perTriggerLoadingConfig,
      fallbackBundleName = fallbackBundleName
    )
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }
}

/**
 * Custom Helium Paywall Delegate that bridges purchase calls to Flutter.
 * Similar to DemoHeliumPaywallDelegate in iOS.
 */
class CustomPaywallDelegate(
  private val methodChannel: MethodChannel
) : HeliumPaywallDelegate {

  override suspend fun makePurchase(
    productDetails: ProductDetails,
    basePlanId: String?,
    offerId: String?
  ): HeliumPaywallTransactionStatus {
    return suspendCancellableCoroutine { continuation ->
      // Build chained product identifier: productId:basePlanId:offerId
      val chainedProductId = buildString {
        append(productDetails.productId)
        if (basePlanId != null) {
          append(":").append(basePlanId)
        }
        if (offerId != null) {
          append(":").append(offerId)
        }
      }

      methodChannel.invokeMethod(
        "makePurchase",
        chainedProductId
      ) { result ->
        val status: HeliumPaywallTransactionStatus = when {
          result is Map<*, *> -> {
            val statusString = result["status"] as? String
            val lowercasedStatus = statusString?.lowercase()

            when (lowercasedStatus) {
              "purchased" -> HeliumPaywallTransactionStatus.Purchased
              "cancelled" -> HeliumPaywallTransactionStatus.Cancelled
              "restored" -> HeliumPaywallTransactionStatus.Restored
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
    }
  }

  override suspend fun restorePurchases(): Boolean {
    return suspendCancellableCoroutine { continuation ->
      methodChannel.invokeMethod(
        "restorePurchases",
        null
      ) { result ->
        val success = (result as? Boolean) ?: false
        continuation.resume(success)
      }
    }
  }
}
