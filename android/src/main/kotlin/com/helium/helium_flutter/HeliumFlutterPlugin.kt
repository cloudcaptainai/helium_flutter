package com.helium.helium_flutter

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collect
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.flow.StateFlow
import kotlin.coroutines.resume
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.helium.helium_flutter.toEnvironment
import com.helium.helium_flutter.convertToHeliumUserTraits
import com.helium.helium_flutter.convertToHeliumUserTraitsArgument
import com.helium.helium_flutter.CustomPaywallDelegate
import com.tryhelium.paywall.core.Helium
import com.tryhelium.paywall.core.HeliumConfigStatus
import com.tryhelium.paywall.core.HeliumConfigStatus.*
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

  private lateinit var statusChannel: EventChannel
  private val mainScope = CoroutineScope(Dispatchers.Main)
  private var statusJob: Job? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    this.flutterPluginBinding = flutterPluginBinding
    this.context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "helium_flutter")
    channel.setMethodCallHandler(this)

    statusChannel =
      EventChannel(flutterPluginBinding.binaryMessenger, "com.tryhelium.paywall/download_status")
    statusChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        if (!Helium.isInitialized) {
          events?.error("NOT_INITIALIZED", "Helium not initialized", null)
          return
        }

        // Cancel the currentJob if one exist
        statusJob?.cancel()

        // Launch a coroutine to collect the Kotlin Flow
        statusJob = mainScope.launch {
          try {
            // Collect the flow and send enum names to Flutter
            Helium.shared.downloadStatus.collect { status ->
              events?.success(status.toStringValue()) // Sends "SUCCESS", "PENDING", etc.
            }
          } catch (e: Exception) {
            // Handle flow errors or cancellation
          }
        }
      }

      override fun onCancel(arguments: Any?) {
        // Stop collecting when Flutter listener cancels
        statusJob?.cancel()
        statusJob = null
      }
    })
  }

  fun HeliumConfigStatus.toStringValue(): String {
    return when (this) {
      DownloadFailure -> "downloadFailure"
      DownloadSuccess -> "downloadSuccess"
      Downloading -> "inProgress"
      NotYetDownloaded -> "notDownloadedYet"
      else -> ""
    }
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

        val environment = (args["environment"] as? String).toEnvironment()

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
        val status = (Helium.shared.downloadStatus as? StateFlow<HeliumConfigStatus>)?.value
        val isLoaded = status is HeliumConfigStatus.DownloadSuccess
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
        val paywallInfo = Helium.shared.getPaywallInfo(trigger)

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
        val handled = Helium.shared.handleDeepLink(uri = urlString)
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
        val experimentInfo = Helium.shared.getExperimentInfoForTrigger(trigger)

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
    
    statusChannel.setStreamHandler(null)
    statusJob?.cancel()
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
