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
    final helium = HeliumFlutter();

    if (helium.isInitialized) {
      log('[HeliumStripe] Helium already initialized, skipping Stripe init.');
      return;
    }

    String? standardInitializeReason;
    if (!_isIOS) {
      standardInitializeReason = 'Stripe One Tap is only available on iOS';
    } else {
      final emptyFields = <String>[
        if (stripePublishableKey.isEmpty) 'stripePublishableKey',
        if (merchantIdentifier.isEmpty) 'merchantIdentifier',
        if (merchantName.isEmpty) 'merchantName',
        if (managementURL.isEmpty) 'managementURL',
      ];
      if (emptyFields.isNotEmpty) {
        standardInitializeReason = 'Empty Stripe config fields: ${emptyFields.join(', ')}';
      }
    }

    if (standardInitializeReason != null) {
      log('[HeliumStripe] $standardInitializeReason. Using standard initialization.');
      await helium.initialize(
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
}
