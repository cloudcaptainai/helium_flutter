package com.helium.helium_flutter

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancelChildren
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
import com.tryhelium.paywall.core.event.HeliumEvent
import com.tryhelium.paywall.core.event.HeliumEventListener
import com.tryhelium.paywall.core.event.HeliumEventDictionaryMapper
import com.tryhelium.paywall.core.HeliumConfigStatus
import com.tryhelium.paywall.core.HeliumConfigStatus.*
import com.tryhelium.paywall.core.HeliumEnvironment
import com.tryhelium.paywall.core.HeliumUserTraits
import com.tryhelium.paywall.core.HeliumUserTraitsArgument
import com.tryhelium.paywall.core.HeliumPaywallTransactionStatus
import com.tryhelium.paywall.core.HeliumLightDarkMode
import com.tryhelium.paywall.core.PaywallPresentationConfig
import com.tryhelium.paywall.delegate.HeliumPaywallDelegate
import com.tryhelium.paywall.delegate.PlayStorePaywallDelegate
import com.tryhelium.paywall.core.logger.HeliumLogger
import com.tryhelium.paywall.core.HeliumWrapperSdkConfig
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
  private var globalEventListener: HeliumEventListener? = null

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

    flutterPluginBinding.platformViewRegistry.registerViewFactory(
        "upsellViewForTrigger",
        HeliumNativeViewFactory(channel)
    )
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
        val revenueCatAppUserId = args["revenueCatAppUserId"] as? String
        val useDefaultDelegate = args["useDefaultDelegate"] as? Boolean ?: false

        @Suppress("UNCHECKED_CAST")
        val customUserTraitsMap = args["customUserTraits"] as? Map<String, Any?>
        val customUserTraits = convertToHeliumUserTraits(customUserTraitsMap)

        @Suppress("UNCHECKED_CAST")
        val paywallLoadingConfigMap = args["paywallLoadingConfig"] as? Map<String, Any?>

        // Extract fallbackAssetPath from args and resolve Flutter asset path
        val fallbackAssetPath = args["fallbackAssetPath"] as? String
        val flutterAssetPath = fallbackAssetPath?.let {
          flutterPluginBinding?.flutterAssets?.getAssetFilePathByName(it)
        }

        val environment = (args["environment"] as? String).toEnvironment()

        val wrapperSdkVersion = args["wrapperSdkVersion"] as? String ?: "unknown"
        val delegateType = args["delegateType"] as? String ?: "custom"

        try {
          val currentContext = context
          val currentActivity = activity

          if (currentContext == null) {
            result.error("NO_CONTEXT", "Context not available", null)
            return
          }

          // Set wrapper SDK info for analytics
          HeliumWrapperSdkConfig.setWrapperSdkInfo(sdk = "flutter", version = wrapperSdkVersion)

          // Parse loading configuration
          val useLoadingState = paywallLoadingConfigMap?.get("useLoadingState") as? Boolean ?: true
          val loadingBudgetSeconds = (paywallLoadingConfigMap?.get("loadingBudget") as? Number)?.toDouble()
          val loadingBudgetMs = loadingBudgetSeconds?.let { (it * 1000).toLong() } ?: DEFAULT_LOADING_BUDGET_MS
          if (!useLoadingState) {
            // Setting <= 0 will disable loading state
            Helium.config.defaultLoadingBudgetInMs = -1
          } else {
            Helium.config.defaultLoadingBudgetInMs = loadingBudgetMs
          }

          // Create and set delegate if needed
          if (!useDefaultDelegate) {
            Helium.config.heliumPaywallDelegate = CustomPaywallDelegate(delegateType, channel)
          }

          // Set custom API endpoint
          customApiEndpoint?.let { Helium.config.customApiEndpoint = it }

          // Set fallback asset path - native SDK reads directly from context.assets
          flutterAssetPath?.let { Helium.config.customFallbacksFileName = it }

          // Set identity
          customUserId?.let { Helium.identity.userId = it }
          customUserTraits?.let { Helium.identity.setUserTraits(it) }
          revenueCatAppUserId?.let { Helium.identity.revenueCatAppUserId = it }

          // Set up bridging logger to forward native SDK logs to Flutter
          Helium.config.logger = BridgingLogger(channel)

          Helium.initialize(
            context = currentContext,
            apiKey = apiKey,
            environment = environment,
          )

          // Add global event listener to forward events to Flutter callbacks
          globalEventListener?.let { Helium.shared.removeHeliumEventListener(it) }
          val listener = HeliumEventListener { event ->
            val eventData = HeliumEventDictionaryMapper.toDictionary(event)
            Handler(Looper.getMainLooper()).post {
              try {
                channel.invokeMethod("onPaywallEvent", eventData)
              } catch (e: Exception) {
                // Channel may be detached, ignore
              }
            }
          }
          globalEventListener = listener
          Helium.shared.addPaywallEventListener(listener)

          result.success("Initialization started!")
        } catch (e: Exception) {
          result.error("INIT_ERROR", "Failed to initialize: ${e.message}", null)
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

        val eventListener = HeliumEventListener { event ->
            // Convert the sealed class object to a Map
            val eventData = HeliumEventDictionaryMapper.toDictionary(event)
            // Send to Flutter on the Main Thread
            Handler(Looper.getMainLooper()).post {
                try {
                    channel.invokeMethod("onPaywallEventHandler", eventData)
                } catch (e: Exception) {
                    // Channel may be detached, ignore
                }
            }
        }

        Helium.presentPaywall(
          trigger = trigger,
          config = PaywallPresentationConfig(
            fromActivityContext = activity,
            customPaywallTraits = customPaywallTraits,
            dontShowIfAlreadyEntitled = dontShowIfAlreadyEntitled
          ),
          eventListener = eventListener,
          onPaywallNotShown = { _ ->
            // nothing for now
          }
        )

        result.success("Upsell presented!")
      }
      "hideUpsell" -> {
        Helium.hidePaywall()
        result.success(true)
      }
      "hideAllUpsells" -> {
        Helium.hideAllPaywalls()
        result.success(true)
      }
      "getHeliumUserId" -> {
        val userId = Helium.identity.userId
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

        Helium.identity.userId = newUserId
        traits?.let { Helium.identity.setUserTraits(it) }

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
        val trigger = call.arguments as? String ?: ""
        val paywallInfo = Helium.shared.getPaywallInfo(trigger)
        val canPresent = paywallInfo?.shouldShow == true
        result.success(mapOf(
          "canShow" to canPresent,
          "isFallback" to false,
//          "paywallUnavailableReason" to paywallInfo.shouldShow //todo improve this
        ))
      }
      "handleDeepLink" -> {
        val urlString = call.arguments as? String
        val handled = Helium.shared.handleDeepLink(uri = urlString)
        result.success(handled)
      }
      "hasAnyActiveSubscription" -> {
        mainScope.launch {
          try {
            val hasSubscription: Boolean = Helium.entitlements.hasAnyActiveSubscription()
            result.success(hasSubscription)
          } catch (e: Exception) {
            result.success(null)
          }
        }
      }
      "hasAnyEntitlement" -> {
        mainScope.launch {
          try {
            val hasEntitlement: Boolean = Helium.entitlements.hasAnyEntitlement()
            result.success(hasEntitlement)
          } catch (e: Exception) {
            result.success(null)
          }
        }
      }
      "hasEntitlementForPaywall" -> {
        val trigger = call.arguments as? String
        if (trigger == null) {
          result.error("BAD_ARGS", "Arguments not passed correctly", null)
          return
        }
        mainScope.launch {
          try {
            val hasEntitlement: Boolean? = Helium.entitlements.hasEntitlementForPaywall(trigger)
            result.success(hasEntitlement)
          } catch (e: Exception) {
            result.success(null)
          }
        }
      }
      "getExperimentInfoForTrigger" -> {
        val trigger = call.arguments as? String ?: ""
        val experimentInfo = Helium.experiments.getExperimentInfoForTrigger(trigger)

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
        Helium.shared.disableRestoreFailedDialog()
        result.success("Restore failed dialog disabled!")
      }
      "setCustomRestoreFailedStrings" -> {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
          result.error("BAD_ARGS", "Arguments not passed correctly", null)
          return
        }
        val customTitle = args["customTitle"] as? String
        val customMessage = args["customMessage"] as? String
        val customCloseButtonText = args["customCloseButtonText"] as? String
        Helium.shared.setCustomRestoreFailedStrings(customTitle = customTitle, customMessage = customMessage, customCloseButtonText = customCloseButtonText)
        result.success("Custom restore failed strings set!")
      }
      "resetHelium" -> {
        // Remove global event listener
        globalEventListener?.let { Helium.shared.removeHeliumEventListener(it) }
        globalEventListener = null
        // Reset logger back to default stdout logger
        Helium.config.logger = HeliumLogger.Stdout
        Helium.resetHelium()
        result.success("Helium reset!")
      }
      "setLightDarkModeOverride" -> {
        val mode = call.arguments as? String ?: ""
        val heliumMode: HeliumLightDarkMode = when (mode.lowercase()) {
          "light" -> HeliumLightDarkMode.LIGHT
          "dark" -> HeliumLightDarkMode.DARK
          "system" -> HeliumLightDarkMode.SYSTEM
          else -> {
            android.util.Log.w("HeliumPaywallSdk", "Invalid light/dark mode: $mode, defaulting to system")
            HeliumLightDarkMode.SYSTEM
          }
        }
        Helium.shared.setLightDarkModeOverride(heliumMode)
        result.success("Light/Dark mode override set!")
      }
      "setRevenueCatAppUserId" -> {
        val rcAppUserId = call.arguments as? String
        if (rcAppUserId == null) {
          result.error("BAD_ARGS", "rcAppUserId not provided", null)
          return
        }
        Helium.identity.revenueCatAppUserId = rcAppUserId
        result.success("RevenueCat App User ID set!")
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    if (::channel.isInitialized) {
      channel.setMethodCallHandler(null)
    }
    this.flutterPluginBinding = null
    this.context = null

    if (::statusChannel.isInitialized) {
      statusChannel.setStreamHandler(null)
    }
    statusJob?.cancel()

    // Cancel any in-flight coroutines (entitlement checks, etc.)
    mainScope.coroutineContext.cancelChildren()

    // Remove global event listener and reset logger to avoid invoking methods on detached channel
    if (Helium.isInitialized) {
      globalEventListener?.let { Helium.shared.removeHeliumEventListener(it) }
      globalEventListener = null
      Helium.config.logger = HeliumLogger.Stdout
    }
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

  companion object {
    private const val DEFAULT_LOADING_BUDGET_MS = 7000L
  }
}
