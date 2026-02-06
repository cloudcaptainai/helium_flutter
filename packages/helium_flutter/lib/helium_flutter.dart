import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:helium_flutter/core/helium_callbacks.dart';
import 'package:helium_flutter/core/helium_flutter_platform.dart';
import 'package:helium_flutter/types/experiment_info.dart';
import 'package:helium_flutter/types/helium_config_status.dart';
import 'package:helium_flutter/types/helium_environment.dart';
import 'package:helium_flutter/types/helium_types.dart';
export './core/helium_callbacks.dart';
export './types/experiment_info.dart';
export './types/helium_transaction_status.dart';
export './types/helium_types.dart';

class HeliumFlutter {
  ///Initialize helium sdk at the start-up of your flutter application.
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
    HeliumEnvironment? environment,
    HeliumPaywallLoadingConfig? paywallLoadingConfig,
  }) async {
    return await HeliumFlutterPlatform.instance.initialize(
      apiKey: apiKey,
      callbacks: callbacks,
      purchaseDelegate: purchaseDelegate,
      fallbackPaywall: fallbackPaywall,
      customAPIEndpoint: customAPIEndpoint,
      customUserId: customUserId,
      customUserTraits: customUserTraits,
      revenueCatAppUserId: revenueCatAppUserId,
      fallbackBundleAssetPath: fallbackBundleAssetPath,
      environment: environment,
      paywallLoadingConfig: paywallLoadingConfig,
    );
  }

  ///Gets helium user id
  Future<String?> getHeliumUserId() =>
      HeliumFlutterPlatform.instance.getHeliumUserId();

  ///Hide currently visible Helium paywall.
  Future<bool> hideUpsell() => HeliumFlutterPlatform.instance.hideUpsell();

  ///Hide all Helium paywalls.
  Future<bool> hideAllUpsells() =>
      HeliumFlutterPlatform.instance.hideAllUpsells();

  ///Overrides user id to given [newUserId]
  Future<String?> overrideUserId({
    required String newUserId,
    Map<String, dynamic>? traits,
  }) =>
      HeliumFlutterPlatform.instance.overrideUserId(
        newUserId: newUserId,
        traits: traits,
      );

  ///Returns true if Helium paywalls are loaded.
  Future<bool> paywallsLoaded() =>
      HeliumFlutterPlatform.instance.paywallsLoaded();

  static const EventChannel _statusChannel =
      EventChannel("com.tryhelium.paywall/download_status");

  ///Download status of paywall
  static Stream<HeliumConfigStatus> get downloadStatus {
    return _statusChannel.receiveBroadcastStream().map((event) {
      return HeliumConfigStatus.create(event as String?);
    });
  }

  ///Presents view based on [trigger]
  Future<String?> presentUpsell({
    required BuildContext context,
    required String trigger,
    PaywallEventHandlers? eventHandlers,
    Map<String, dynamic>? customPaywallTraits,
    bool? dontShowIfAlreadyEntitled,
  }) =>
      HeliumFlutterPlatform.instance.presentUpsell(
        context: context,
        trigger: trigger,
        eventHandlers: eventHandlers,
        customPaywallTraits: customPaywallTraits,
        dontShowIfAlreadyEntitled: dontShowIfAlreadyEntitled,
      );

  Future<PaywallInfo?> getPaywallInfo(String trigger) =>
      HeliumFlutterPlatform.instance.getPaywallInfo(trigger);

  Future<bool> handleDeepLink(String uri) =>
      HeliumFlutterPlatform.instance.handleDeepLink(uri);

  Widget getUpsellWidget({
    required String trigger,
    PaywallEventHandlers? eventHandlers,
  }) =>
      HeliumFlutterPlatform.instance
          .getUpsellWidget(trigger: trigger, eventHandlers: eventHandlers);

  /// Checks if the user has any active subscription (including non-renewable)
  Future<bool> hasAnyActiveSubscription() =>
      HeliumFlutterPlatform.instance.hasAnyActiveSubscription();

  /// Checks if the user has any entitlement
  Future<bool> hasAnyEntitlement() =>
      HeliumFlutterPlatform.instance.hasAnyEntitlement();

  /// Checks if the user has an active entitlement for any product attached to the paywall that will show for provided trigger.
  /// - Parameter trigger: Trigger that would be used to show the paywall.
  /// - Returns: `true` if the user has bought one of the products on the paywall. `false` if not. Returns `null` if not known (i.e. the paywall is not downloaded yet).
  Future<bool?> hasEntitlementForPaywall(String trigger) =>
      HeliumFlutterPlatform.instance.hasEntitlementForPaywall(trigger);

  /// Get experiment allocation info for a specific trigger
  ///
  /// - Parameter trigger: The trigger name to get experiment info for
  /// - Returns: ExperimentInfo if the trigger has experiment data, nil otherwise
  Future<ExperimentInfo?> getExperimentInfoForTrigger(String trigger) =>
      HeliumFlutterPlatform.instance.getExperimentInfoForTrigger(trigger);

  /// Disable the default dialog that Helium will display if a "Restore Purchases" action is not successful.
  /// You can handle this yourself if desired by listening for the PurchaseRestoreFailedEvent.
  void disableRestoreFailedDialog() =>
      HeliumFlutterPlatform.instance.disableRestoreFailedDialog();

  /// Set custom strings to show in the dialog that Helium will display if a "Restore Purchases" action is not successful.
  /// Note that these strings will not be localized by Helium for you.
  void setCustomRestoreFailedStrings({
    String? customTitle,
    String? customMessage,
    String? customCloseButtonText,
  }) =>
      HeliumFlutterPlatform.instance.setCustomRestoreFailedStrings(
        customTitle: customTitle,
        customMessage: customMessage,
        customCloseButtonText: customCloseButtonText,
      );

  /// Reset Helium entirely so you can call initialize again. Only for advanced use cases.
  Future<void> resetHelium() => HeliumFlutterPlatform.instance.resetHelium();

  /// Sets light/dark mode override for Helium paywalls.
  /// - Parameter mode: The desired appearance mode (.light, .dark, or .system)
  /// - Note: .system respects the device's current appearance setting (default)
  void setLightDarkModeOverride(HeliumLightDarkMode mode) =>
      HeliumFlutterPlatform.instance.setLightDarkModeOverride(mode);

  /// Set RevenueCat App User ID to improve Helium revenue attribution.
  /// - Parameter rcAppUserId: RevenueCat App User ID (e.g. await Purchases.appUserID)
  void setRevenueCatAppUserId(String rcAppUserId) =>
      HeliumFlutterPlatform.instance.setRevenueCatAppUserId(rcAppUserId);
}
