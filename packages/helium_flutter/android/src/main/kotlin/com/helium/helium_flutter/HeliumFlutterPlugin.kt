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
import com.tryhelium.paywall.core.event.PaywallEventHandlers
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
import com.tryhelium.paywall.core.IActivityProvider
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
  private var nativeViewFactory: HeliumNativeViewFactory? = null

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

    val factory = HeliumNativeViewFactory(channel)
    nativeViewFactory = factory
    flutterPluginBinding.platformViewRegistry.registerViewFactory(
        "upsellViewForTrigger",
        factory
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
        val parsed = parseInitArgs(args) ?: run {
          result.error("NO_CONTEXT", "Context not available", null)
          return
        }
        try {
          setupCore(parsed)
          Helium.initialize(
            context = parsed.context,
            apiKey = parsed.apiKey,
            environment = parsed.environment,
          )
          setupGlobalEventListener()
          result.success("Initialization started!")
        } catch (e: Exception) {
          android.util.Log.e("HeliumFlutter", "Failed to initialize", e)
          result.error("INIT_ERROR", "Failed to initialize: ${e.message}", null)
        }
      }
      "setupCore" -> {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
          result.error("BAD_ARGS", "Arguments not passed correctly", null)
          return
        }
        val parsed = parseInitArgs(args) ?: run {
          result.error("NO_CONTEXT", "Context not available", null)
          return
        }
        try {
          setupCore(parsed)
          setupGlobalEventListener()
          result.success("Core setup complete!")
        } catch (e: Exception) {
          android.util.Log.e("HeliumFlutter", "Failed to setup core", e)
          result.error("SETUP_ERROR", "Failed to setup core: ${e.message}", null)
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

        val eventListener = PaywallEventHandlers(onAnyEvent = { event ->
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
        })

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
        val args = call.arguments as? Map<*, *>
        val clearUserTraits = args?.get("clearUserTraits") as? Boolean ?: true
        val clearHeliumEventListeners = args?.get("clearHeliumEventListeners") as? Boolean ?: true
        val clearExperimentAllocations = args?.get("clearExperimentAllocations") as? Boolean ?: false

        // Remove global event listener
        globalEventListener?.let { Helium.shared.removeHeliumEventListener(it) }
        globalEventListener = null
        // Reset logger so initialize() can set up a fresh BridgingLogger
        Helium.config.logger = HeliumLogger.Stdout

        mainScope.launch {
          try {
            suspendCancellableCoroutine { continuation ->
              Helium.resetHelium(
                clearUserTraits = clearUserTraits,
                clearHeliumEventListeners = clearHeliumEventListeners,
                clearExperimentAllocations = clearExperimentAllocations,
                onComplete = {
                  if (continuation.isActive) {
                    continuation.resume(Unit)
                  }
                }
              )
            }
            result.success("Helium reset!")
          } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
          } catch (e: Exception) {
            result.error("RESET_ERROR", "resetHelium failed: ${e.message}", null)
          }
        }
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
      "setAndroidConsumableProductIds" -> {
        @Suppress("UNCHECKED_CAST")
        val productIds = call.arguments as? List<String> ?: emptyList()
        Helium.config.consumableIds = productIds.toSet()
        result.success("Android consumable product IDs set!")
      }
      "setUserTraits" -> {
        try {
          @Suppress("UNCHECKED_CAST")
          val traitsMap = call.arguments as? Map<String, Any?>
          val traits = convertToHeliumUserTraits(traitsMap)
          traits?.let { Helium.identity.setUserTraits(it) }
          result.success("User traits updated!")
        } catch (e: Exception) {
          android.util.Log.e("HeliumFlutter", "Failed to set user traits", e)
          result.error("SET_TRAITS_ERROR", "Failed to set user traits: ${e.message}", null)
        }
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
    nativeViewFactory?.activity = null
    nativeViewFactory = null

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
    nativeViewFactory?.activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
    nativeViewFactory?.activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    nativeViewFactory?.activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
    nativeViewFactory?.activity = null
  }

  private data class ParsedInitArgs(
    val context: Context,
    val apiKey: String,
    val customApiEndpoint: String?,
    val customUserId: String?,
    val revenueCatAppUserId: String?,
    val useDefaultDelegate: Boolean,
    val customUserTraits: HeliumUserTraits?,
    val paywallLoadingConfigMap: Map<String, Any?>?,
    val flutterAssetPath: String?,
    val environment: HeliumEnvironment,
    val wrapperSdkVersion: String,
    val delegateType: String,
    val consumableProductIds: List<String>?,
  )

  private fun parseInitArgs(args: Map<*, *>): ParsedInitArgs? {
    val currentContext = context ?: return null

    val fallbackAssetPath = args["fallbackAssetPath"] as? String
    val flutterAssetPath = fallbackAssetPath?.let {
      flutterPluginBinding?.flutterAssets?.getAssetFilePathByName(it)
    }

    @Suppress("UNCHECKED_CAST")
    val customUserTraitsMap = args["customUserTraits"] as? Map<String, Any?>

    @Suppress("UNCHECKED_CAST")
    val paywallLoadingConfigMap = args["paywallLoadingConfig"] as? Map<String, Any?>

    @Suppress("UNCHECKED_CAST")
    val consumableProductIds = args["androidConsumableProductIds"] as? List<String>

    return ParsedInitArgs(
      context = currentContext,
      apiKey = args["apiKey"] as? String ?: "",
      customApiEndpoint = args["customAPIEndpoint"] as? String,
      customUserId = args["customUserId"] as? String,
      revenueCatAppUserId = args["revenueCatAppUserId"] as? String,
      useDefaultDelegate = args["useDefaultDelegate"] as? Boolean ?: false,
      customUserTraits = convertToHeliumUserTraits(customUserTraitsMap),
      paywallLoadingConfigMap = paywallLoadingConfigMap,
      flutterAssetPath = flutterAssetPath,
      environment = (args["environment"] as? String).toEnvironment(),
      wrapperSdkVersion = args["wrapperSdkVersion"] as? String ?: "unknown",
      delegateType = args["delegateType"] as? String ?: "custom",
      consumableProductIds = consumableProductIds,
    )
  }

  private fun setupCore(parsed: ParsedInitArgs) {
    // Set wrapper SDK info for analytics
    HeliumWrapperSdkConfig.setWrapperSdkInfo(sdk = "flutter", version = parsed.wrapperSdkVersion)

    // Parse loading configuration
    val useLoadingState = parsed.paywallLoadingConfigMap?.get("useLoadingState") as? Boolean ?: true
    val loadingBudgetSeconds = (parsed.paywallLoadingConfigMap?.get("loadingBudget") as? Number)?.toDouble()
    val loadingBudgetMs = loadingBudgetSeconds?.let { (it * 1000).toLong() } ?: DEFAULT_LOADING_BUDGET_MS
    if (!useLoadingState) {
      Helium.config.defaultLoadingBudgetInMs = -1
    } else {
      Helium.config.defaultLoadingBudgetInMs = loadingBudgetMs
    }

    // Always write API endpoint (null clears a previous override)
    Helium.config.customApiEndpoint = parsed.customApiEndpoint

    // Always write fallback asset path (null clears a previous override)
    Helium.config.customFallbacksFileName = parsed.flutterAssetPath

    // Set identity
    parsed.customUserId?.let { Helium.identity.userId = it }
    parsed.customUserTraits?.let { Helium.identity.setUserTraits(it) }
    parsed.revenueCatAppUserId?.let { Helium.identity.revenueCatAppUserId = it }

    // Always write consumable product IDs (empty set clears previous values)
    Helium.config.consumableIds = parsed.consumableProductIds?.toSet() ?: emptySet()

    // Set up bridging logger to forward native SDK logs to Flutter
    Helium.config.logger = BridgingLogger(channel)

    // Create and set delegate.
    // When useDefaultDelegate is true, we still explicitly create a PlayStorePaywallDelegate
    // so that its activityProvider can use the Flutter plugin's activity reference
    // (needed for embedded-view flows where the SDK's ActivityLifecycleTracker may not
    // have the current activity).
    if (!parsed.useDefaultDelegate) {
      Helium.config.heliumPaywallDelegate = CustomPaywallDelegate(parsed.delegateType, channel)
    } else {
      Helium.config.heliumPaywallDelegate = PlayStorePaywallDelegate(
        activityProvider = {
          IActivityProvider {
            // Prefer the Flutter plugin's activity reference (needed for embedded-view
            // flows), then check the SDK's tracker (picks up new Activities launched by
            // presentPaywall).
            activity?.takeIf { !it.isFinishing }
              ?: Helium.activityTracker?.getCurrentActivity()
          }
        },
        context = parsed.context,
        consumableIds = Helium.config.consumableIds,
        logger = Helium.config.logger
      )
    }
  }

  private fun setupGlobalEventListener() {
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
    Helium.shared.addHeliumEventListener(listener)
  }

  companion object {
    private const val DEFAULT_LOADING_BUDGET_MS = 7000L
  }
}
