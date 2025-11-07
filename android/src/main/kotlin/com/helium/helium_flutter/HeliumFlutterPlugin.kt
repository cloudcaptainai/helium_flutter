package com.helium.helium_flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** HeliumFlutterPlugin */
class HeliumFlutterPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "helium_flutter")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "initialize" -> {
        result.notImplemented()
      }
      "getDownloadStatus" -> {
        result.notImplemented()
      }
      "presentUpsell" -> {
        result.notImplemented()
      }
      "hideUpsell" -> {
        result.notImplemented()
      }
      "getHeliumUserId" -> {
        result.notImplemented()
      }
      "paywallsLoaded" -> {
        result.notImplemented()
      }
      "overrideUserId" -> {
        result.notImplemented()
      }
      "fallbackOpenEvent" -> {
        result.notImplemented()
      }
      "fallbackCloseEvent" -> {
        result.notImplemented()
      }
      "getPaywallInfo" -> {
        result.notImplemented()
      }
      "canPresentUpsell" -> {
        result.notImplemented()
      }
      "handleDeepLink" -> {
        result.notImplemented()
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
        result.notImplemented()
      }
      "disableRestoreFailedDialog" -> {
        result.notImplemented()
      }
      "setCustomRestoreFailedStrings" -> {
        result.notImplemented()
      }
      "resetHelium" -> {
        result.notImplemented()
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
  }
}
