import 'package:flutter/material.dart';
import 'package:helium_flutter/core/helium_callbacks.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../types/experiment_info.dart';
import '../types/helium_types.dart';
import 'helium_flutter_method_channel.dart';

abstract class HeliumFlutterPlatform extends PlatformInterface {
  /// Constructs a HeliumFlutterPlatform.
  HeliumFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static HeliumFlutterPlatform _instance = HeliumFlutterMethodChannel();

  /// The default instance of [HeliumFlutterPlatform] to use.
  ///
  /// Defaults to [HeliumFlutterMethodChannel].
  static HeliumFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [HeliumFlutterPlatform] when
  /// they register themselves.
  static set instance(HeliumFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  ///Initialize helium sdk at the start up of flutter application. It will download custom paywall view
  Future<String?> initialize({
    required String apiKey,
    HeliumCallbacks? callbacks,
    HeliumPurchaseDelegate? purchaseDelegate,
    Widget? fallbackPaywall,
    String? customAPIEndpoint,
    String? customUserId,
    Map<String, dynamic>? customUserTraits,
    String? revenueCatAppUserId,
    String? fallbackBundleAssetPath,
    HeliumPaywallLoadingConfig? paywallLoadingConfig,
  });

  ///Download status of paywall
  Future<String?> getDownloadStatus();

  ///Presents view based on [trigger]
  Future<String?> presentUpsell({
    required BuildContext context,
    required String trigger,
    PaywallEventHandlers? eventHandlers,
    Map<String, dynamic>? customPaywallTraits,
    bool? dontShowIfAlreadyEntitled,
  });

  ///Hides view
  Future<bool> hideUpsell();

  ///Gets helium user id
  Future<String?> getHeliumUserId();

  ///Returns bool based on paywall loaded or not
  Future<bool> paywallsLoaded();

  ///Overrides user id to given [newUserId]
  Future<String?> overrideUserId({
    required String newUserId,
    required Map<String, dynamic> traits,
  });

  Future<PaywallInfo?> getPaywallInfo(String trigger);

  Future<bool> handleDeepLink(String uri);

  Widget getUpsellWidget({
    required String trigger,
    PaywallEventHandlers? eventHandlers,
  });

  Future<bool> hasAnyActiveSubscription();

  Future<bool> hasAnyEntitlement();

  Future<ExperimentInfo?> getExperimentInfoForTrigger(String trigger);

  void disableRestoreFailedDialog();

  void setCustomRestoreFailedStrings({
    String? customTitle,
    String? customMessage,
    String? customCloseButtonText,
  });

  void resetHelium();
}
