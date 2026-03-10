import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:helium_flutter/types/helium_environment.dart';

/// Helium Stripe One Tap Purchase integration for Flutter (iOS only).
///
/// On non-iOS platforms, methods either fall back to standard Helium
/// initialization or return safe defaults.
class HeliumStripe {
  static const MethodChannel _channel = MethodChannel('helium_stripe');

  /// Override for testing. When non-null, used instead of [Platform.isIOS].
  @visibleForTesting
  static bool? isIOSOverride;

  static bool get _isIOS => isIOSOverride ?? Platform.isIOS;

  /// Initializes Helium with Stripe One Tap Purchase support.
  ///
  /// On iOS, this configures Stripe One Tap and initializes Helium with Stripe
  /// integration. On other platforms, falls back to standard [HeliumFlutter.initialize].
  ///
  /// The [apiKey], [stripePublishableKey], [merchantIdentifier], [merchantName],
  /// and [managementURL] parameters are required.
  static Future<void> initializeWithStripe({
    required String apiKey,
    required String stripePublishableKey,
    required String merchantIdentifier,
    required String merchantName,
    required String managementURL,
    String countryCode = 'US',
    String currencyCode = 'USD',
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
    if (!_isIOS) {
      log('[HeliumStripe] Stripe One Tap is only available on iOS. Using standard initialization.');
      await HeliumFlutter().initialize(
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
      return;
    }

    final helium = HeliumFlutter();

    if (helium.isInitialized) {
      log('[HeliumStripe] Helium already initialized, skipping Stripe init.');
      return;
    }

    // Set up core Helium configuration (delegates, callbacks, identity, etc.)
    // without calling Helium.shared.initialize(), since the Stripe native
    // plugin will call Helium.shared.initializeWithStripeOneTap() instead.
    await helium.setupCore(
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

    // Initialize Helium with Stripe One Tap (the single native init call)
    try {
      await _channel.invokeMethod('initializeStripe', {
        'apiKey': apiKey,
        'stripePublishableKey': stripePublishableKey,
        'merchantIdentifier': merchantIdentifier,
        'merchantName': merchantName,
        'managementURL': managementURL,
        'countryCode': countryCode,
        'currencyCode': currencyCode,
      });
    } catch (e) {
      await helium.resetHelium();
      rethrow;
    }
  }

  /// Sets the user ID and syncs Stripe entitlements if needed.
  ///
  /// On non-iOS platforms, falls back to [HeliumFlutter.overrideUserId].
  static void setUserIdAndSyncStripeIfNeeded(String userId) {
    if (!_isIOS) {
      HeliumFlutter().overrideUserId(newUserId: userId);
      return;
    }
    _channel.invokeMethod('setUserIdAndSyncStripeIfNeeded', userId);
  }

  /// Resets Stripe entitlements. Optionally clears the user ID.
  ///
  /// Only available on iOS. No-op on other platforms.
  static void resetStripeEntitlements({bool clearUserId = false}) {
    if (!_isIOS) {
      log('[HeliumStripe] resetStripeEntitlements is only available on iOS');
      return;
    }
    _channel.invokeMethod('resetStripeEntitlements', clearUserId);
  }

  /// Creates a Stripe customer portal session and returns the URL.
  ///
  /// Only available on iOS. Returns `null` on other platforms.
  static Future<String?> createStripePortalSession(String returnUrl) async {
    if (!_isIOS) {
      log('[HeliumStripe] createStripePortalSession is only available on iOS');
      return null;
    }
    try {
      return await _channel.invokeMethod<String>(
          'createStripePortalSession', returnUrl);
    } on PlatformException catch (e) {
      log('[HeliumStripe] Failed to create Stripe portal session: ${e.message}');
      return null;
    }
  }

  /// Returns whether the user has an active Stripe entitlement.
  ///
  /// Only available on iOS. Returns `false` on other platforms.
  static Future<bool> hasActiveStripeEntitlement() async {
    if (!_isIOS) {
      log('[HeliumStripe] hasActiveStripeEntitlement is only available on iOS');
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('hasActiveStripeEntitlement') ??
          false;
    } on PlatformException catch (e) {
      log('[HeliumStripe] Failed to check Stripe entitlement: ${e.message}');
      return false;
    }
  }
}
