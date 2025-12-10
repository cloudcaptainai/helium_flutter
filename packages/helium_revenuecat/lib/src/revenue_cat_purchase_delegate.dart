import 'package:flutter/services.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:developer';

/// RevenueCat implementation of [HeliumPurchaseDelegate].
///
/// Handles purchases through RevenueCat's SDK, supporting both iOS and Android
/// platforms with proper handling of Android subscription options (base plans
/// and offers).
class RevenueCatPurchaseDelegate extends HeliumPurchaseDelegate {
  Future<HeliumPurchaseResult> purchaseProduct(String productId) async {
    try {
      log('[Helium] Making purchase with RevenueCat for: $productId');
      final products = await Purchases.getProducts([productId]);
      if (products.isEmpty) {
        return _createFailedResult('Product not found: $productId');
      }

      final customerInfo = await Purchases.purchaseStoreProduct(products.first);
      return _evaluatePurchaseResult(customerInfo, productId);
    } on PlatformException catch (e) {
      return _handlePlatformException(e);
    } catch (e) {
      return _createFailedResult('Purchase error: ${e.toString()}');
    }
  }

  @override
  Future<HeliumPurchaseResult> makePurchaseAndroid(
    String productId, {
    String? basePlanId,
    String? offerId,
  }) async {
    // Keep this value as up-to-date as possible
    HeliumFlutter().setRevenueCatAppUserId(await Purchases.appUserID);

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
          final customerInfo =
              await Purchases.purchaseSubscriptionOption(subscriptionOption);
          return _evaluatePurchaseResult(customerInfo, productId);
        }
        log('[Helium] No matching subscription option found');
      }

      // Try non-subscription (INAPP) product; most likely not a sub at this point
      var products = await Purchases.getProducts(
        [productId],
        productCategory: ProductCategory.nonSubscription,
      );
      if (products.isNotEmpty) {
        final customerInfo = await Purchases.purchaseStoreProduct(products.first);
        return _evaluatePurchaseResult(customerInfo, productId);
      }

      // Then try subscription product (let RC pick option since we couldn't find a match)
      products = await Purchases.getProducts([productId]);
      if (products.isNotEmpty) {
        final customerInfo = await Purchases.purchaseStoreProduct(products.first);
        return _evaluatePurchaseResult(customerInfo, productId);
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
    // Keep this value as up-to-date as possible
    HeliumFlutter().setRevenueCatAppUserId(await Purchases.appUserID);
    return purchaseProduct(productId);
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
  ///
  /// Matching React Native's thorough approach - checks:
  /// 1. Entitlements for this specific product
  /// 2. Active subscriptions
  /// 3. All purchased product identifiers
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
      CustomerInfo customerInfo, String productId) {
    if (_isProductActive(customerInfo, productId)) {
      return HeliumPurchaseResult(status: HeliumTransactionStatus.purchased);
    }
    return HeliumPurchaseResult(
      status: HeliumTransactionStatus.failed,
      error:
          '[RevenueCat] Purchase possibly complete but entitlement/subscription not active for this product.',
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
}
