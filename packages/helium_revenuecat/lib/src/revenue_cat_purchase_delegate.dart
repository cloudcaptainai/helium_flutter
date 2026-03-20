import 'dart:async';

import 'package:flutter/services.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:developer';

/// RevenueCat implementation of [HeliumPurchaseDelegate].
///
/// Handles purchases through RevenueCat's SDK, supporting both iOS and Android
/// platforms with proper handling of Android subscription options (base plans
/// and offers).
class RevenueCatPurchaseDelegate extends HeliumPurchaseDelegate
    implements HeliumCallbacks {
  @override
  String get delegateType => 'h_revenuecat';

  final bool _stripePurchaseSyncDisabled;
  bool _isSyncingStripePurchase = false;

  /// Creates a new [RevenueCatPurchaseDelegate].
  ///
  /// Set [disableStripePurchaseSync] to `true` to disable automatic RevenueCat
  /// entitlement syncing after Stripe purchases.
  RevenueCatPurchaseDelegate({
    bool disableStripePurchaseSync = false,
  }) : _stripePurchaseSyncDisabled = disableStripePurchaseSync {
    _syncAppUserId();
  }

  /// Syncs the RevenueCat app user ID with Helium.
  Future<void> _syncAppUserId() async {
    final rcSetUp = await Purchases.isConfigured;
    if (!rcSetUp) {
      return;
    }
    HeliumFlutter().setRevenueCatAppUserId(await Purchases.appUserID);
  }

  @override
  Future<HeliumPurchaseResult> makePurchaseAndroid(
    String productId, {
    String? basePlanId,
    String? offerId,
  }) async {
    await _syncAppUserId();

    log('[Helium] RevenueCat Android purchase: productId=$productId, '
        'basePlanId=$basePlanId, offerId=$offerId');

    try {
      // If basePlanId or offerId provided, try to find matching subscription option
      if (basePlanId != null || offerId != null) {
        final subscriptionOption = await _findAndroidSubscriptionOption(
          productId,
          basePlanId,
          offerId,
        );

        if (subscriptionOption != null) {
          final purchaseResult =
              await Purchases.purchase(PurchaseParams.subscriptionOption(subscriptionOption));
          return _evaluatePurchaseResult(purchaseResult.customerInfo, productId);
        }
        log('[Helium] No matching subscription option found');
      }

      // Try non-subscription (INAPP) product; most likely not a sub at this point
      var products = await Purchases.getProducts(
        [productId],
        productCategory: ProductCategory.nonSubscription,
      );
      if (products.isNotEmpty) {
        final purchaseResult = await Purchases.purchase(PurchaseParams.storeProduct(products.first));
        return _evaluatePurchaseResult(purchaseResult.customerInfo, productId);
      }

      // Then try subscription product (let RC pick option since we couldn't find a match)
      products = await Purchases.getProducts([productId]);
      if (products.isNotEmpty) {
        final purchaseResult = await Purchases.purchase(PurchaseParams.storeProduct(products.first));
        return _evaluatePurchaseResult(purchaseResult.customerInfo, productId);
      }

      return _createFailedResult('Android product not found: $productId');
    } on PlatformException catch (e) {
      return _handlePlatformException(e);
    } catch (e) {
      return _createFailedResult('Android purchase error: ${e.toString()}');
    }
  }

  @override
  Future<HeliumPurchaseResult> makePurchaseIOS(String productId) async {
    await _syncAppUserId();

    try {
      log('[Helium] Making iOS purchase with RevenueCat for: $productId');
      final products = await Purchases.getProducts([productId]);
      if (products.isEmpty) {
        return _createFailedResult('Product not found: $productId');
      }

      final purchaseResult = await Purchases.purchase(PurchaseParams.storeProduct(products.first));
      final transactionId = purchaseResult.storeTransaction.transactionIdentifier;
      return _evaluatePurchaseResult(purchaseResult.customerInfo, productId, transactionId: transactionId);
    } on PlatformException catch (e) {
      return _handlePlatformException(e);
    } catch (e) {
      return _createFailedResult('iOS purchase error: ${e.toString()}');
    }
  }

  @override
  Future<bool> restorePurchases() async {
    try {
      log('[RevenueCat] Restoring purchases');
      final restoredInfo = await Purchases.restorePurchases();
      return restoredInfo.entitlements.active.isNotEmpty;
    } catch (e) {
      log('[RevenueCat] Restore error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Private Helper Methods
  // ---------------------------------------------------------------------------

  /// Finds a matching Android subscription option.
  ///
  /// RevenueCat subscription option IDs follow the format:
  /// - `basePlanId` for base plans without offers
  /// - `basePlanId:offerId` for offers
  ///
  /// RC may return multiple products if multiple base plans exist.
  Future<SubscriptionOption?> _findAndroidSubscriptionOption(
    String productId,
    String? basePlanId,
    String? offerId,
  ) async {
    try {
      final products = await Purchases.getProducts([productId]);
      if (products.isEmpty) return null;

      // RC may return multiple products for multiple base plans
      final allSubscriptionOptions = products
          .expand(
              (product) => product.subscriptionOptions ?? <SubscriptionOption>[])
          .toList();

      if (allSubscriptionOptions.isEmpty) return null;

      SubscriptionOption? subscriptionOption;

      // Priority 1: Look for "basePlanId:offerId" if both provided
      if (offerId != null && basePlanId != null) {
        final targetId = '$basePlanId:$offerId';
        subscriptionOption = allSubscriptionOptions
            .cast<SubscriptionOption?>()
            .firstWhere((opt) => opt?.id == targetId, orElse: () => null);
      }

      // Priority 2: Look for just basePlanId
      if (subscriptionOption == null && basePlanId != null) {
        subscriptionOption = allSubscriptionOptions
            .cast<SubscriptionOption?>()
            .firstWhere((opt) => opt?.id == basePlanId, orElse: () => null);
      }

      return subscriptionOption;
    } catch (e) {
      log('[Helium] Error finding RevenueCat subscription option: $e');
      return null;
    }
  }

  /// Checks if a specific product is active in the customer info.
  bool _isProductActive(CustomerInfo customerInfo, String productId) {
    // Check entitlements for this specific product
    final hasActiveEntitlement = customerInfo.entitlements.active.values
        .any((entitlement) => entitlement.productIdentifier == productId);

    // Check active subscriptions
    final hasActiveSubscription =
        customerInfo.activeSubscriptions.contains(productId);

    // Check all purchased products
    final wasPurchased =
        customerInfo.allPurchasedProductIdentifiers.contains(productId);

    return hasActiveEntitlement || hasActiveSubscription || wasPurchased;
  }

  /// Evaluates customer info to determine purchase result.
  HeliumPurchaseResult _evaluatePurchaseResult(
      CustomerInfo customerInfo, String productId, {String? transactionId}) {
    if (!_isProductActive(customerInfo, productId)) {
      log('[Helium] Purchase succeeded but product not immediately active in customerInfo: $productId');
    }
    return HeliumPurchaseResult(
      status: HeliumTransactionStatus.purchased,
      transactionId: transactionId,
      productId: productId,
    );
  }

  /// Handles RevenueCat platform exceptions.
  HeliumPurchaseResult _handlePlatformException(PlatformException e) {
    final errorCode = PurchasesErrorHelper.getErrorCode(e);

    switch (errorCode) {
      case PurchasesErrorCode.purchaseCancelledError:
        return HeliumPurchaseResult(status: HeliumTransactionStatus.cancelled);
      case PurchasesErrorCode.paymentPendingError:
        return HeliumPurchaseResult(status: HeliumTransactionStatus.pending);
      default:
        return _createFailedResult(e.message ?? 'Unknown error');
    }
  }

  /// Creates a failed result with an error message.
  HeliumPurchaseResult _createFailedResult(String error) {
    return HeliumPurchaseResult(
      status: HeliumTransactionStatus.failed,
      error: '[RevenueCat] $error',
    );
  }

  // ---------------------------------------------------------------------------
  // Stripe Auto-Syncing
  // ---------------------------------------------------------------------------

  @override
  void onPaywallEvent(HeliumPaywallEvent event) {
    if (!_stripePurchaseSyncDisabled &&
        event.type == 'purchaseSucceeded' &&
        _isStripePurchase(event)) {
      _syncRevenueCatAfterStripePurchase();
    }
  }

  bool _isStripePurchase(HeliumPaywallEvent event) {
    final txId = event.canonicalJoinTransactionId;
    if (txId != null && txId.startsWith('si_')) {
      return true;
    }
    final pid = event.productId;
    if (pid != null && RegExp(r'^prod_\w+:price_\w+$').hasMatch(pid)) {
      return true;
    }
    return false;
  }

  /// After a Stripe purchase completes, the RevenueCat SDK on-device has no way
  /// to know that a new entitlement exists until its backend processes the Stripe
  /// webhook. This method polls RevenueCat with progressive back-off to force a
  /// customer info refresh, stopping early if the update listener fires
  /// (~50s max).
  Future<void> _syncRevenueCatAfterStripePurchase() async {
    if (_isSyncingStripePurchase) return;
    _isSyncingStripePurchase = true;

    try {
      bool synced = false;
      bool hasInvalidatedCache = false;

      void listener(CustomerInfo info) {
        // The Flutter RC SDK fires the listener immediately with cached data
        // on subscribe. Ignore emissions until we've invalidated the cache,
        // so we only react to fresh updates triggered by our polling.
        if (!hasInvalidatedCache) return;
        synced = true;
      }

      Purchases.addCustomerInfoUpdateListener(listener);

      Future<void> pollPhase(int attempts, Duration interval) async {
        for (int i = 0; i < attempts && !synced; i++) {
          await Future<void>.delayed(interval);
          if (synced) break;
          try {
            hasInvalidatedCache = true;
            await Purchases.invalidateCustomerInfoCache();
            await Purchases.getCustomerInfo();
          } catch (e) {
            // Swallow unexpected errors like network failures
          }
        }
      }

      try {
        await pollPhase(5, const Duration(seconds: 1));
        await pollPhase(3, const Duration(seconds: 5));
        await pollPhase(2, const Duration(seconds: 15));
      } finally {
        Purchases.removeCustomerInfoUpdateListener(listener);
      }
    } catch (e) {
      log('[Helium] Error syncing RevenueCat after Stripe purchase: $e');
    } finally {
      _isSyncingStripePurchase = false;
    }
  }

}
