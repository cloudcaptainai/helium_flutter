import 'package:flutter/services.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:developer';

/// RevenueCat implementation of [HeliumPurchaseDelegate].
///
/// Handles purchases through RevenueCat's SDK, supporting both iOS and Android
/// platforms with proper handling of Android subscription options (base plans
/// and offers).
class RevenueCatPurchaseDelegate implements HeliumPurchaseDelegate {
  @override
  Future<HeliumPurchaseResult> makePurchase(String productId) async {
    try {
      log('[RevenueCat] Making purchase: $productId');
      return await _purchaseProduct(productId);
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
    try {
      // RevenueCat uses format: <product_id>:<base_plan_id>
      final revenueCatProductId = _buildAndroidProductId(productId, basePlanId);

      log('[RevenueCat] Android purchase: productId=$productId, '
          'basePlanId=$basePlanId, offerId=$offerId, '
          'revenueCatProductId=$revenueCatProductId');

      // If no offer specified, use standard purchase flow
      if (offerId == null || offerId.isEmpty) {
        return await _purchaseProduct(revenueCatProductId);
      }

      // With offer specified, use subscription options flow
      return await _purchaseWithOffer(revenueCatProductId, offerId);
    } on PlatformException catch (e) {
      return _handlePlatformException(e);
    } catch (e) {
      return _createFailedResult('Android purchase error: ${e.toString()}');
    }
  }

  @override
  Future<HeliumPurchaseResult> makePurchaseIOS(String productId) async {
    return makePurchase(productId);
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

  /// Builds the RevenueCat product identifier for Android subscriptions.
  /// Format: `product_id:base_plan_id` or just `product_id` if no base plan.
  ///
  /// Guards against double-concatenation if productId already contains the basePlanId.
  String _buildAndroidProductId(String productId, String? basePlanId) {
    if (basePlanId == null || basePlanId.isEmpty) {
      return productId;
    }

    // Guard: avoid double-concatenation if productId already ends with :basePlanId
    final expectedSuffix = ':$basePlanId';
    if (productId.endsWith(expectedSuffix)) {
      log('[RevenueCat] Warning: productId already contains basePlanId suffix');
      return productId;
    }

    return '$productId:$basePlanId';
  }

  /// Standard purchase flow - fetches product directly and purchases it.
  Future<HeliumPurchaseResult> _purchaseProduct(String productId) async {
    final product = await _fetchProduct(productId);
    if (product == null) {
      return _createFailedResult('Product not found: $productId');
    }

    final customerInfo = await Purchases.purchaseStoreProduct(product);
    return _evaluatePurchaseResult(customerInfo);
  }

  /// Purchase with a specific subscription offer.
  ///
  /// IMPORTANT: If the requested offer is not found, this method fails explicitly
  /// to prevent accidentally charging full price when user expects a discount.
  Future<HeliumPurchaseResult> _purchaseWithOffer(
    String productId,
    String offerId,
  ) async {
    final product = await _fetchProduct(productId);
    if (product == null) {
      return _createFailedResult('Product not found: $productId');
    }

    final subscriptionOption = _findSubscriptionOption(product, offerId);
    if (subscriptionOption == null) {
      // SAFETY: Fail explicitly - do NOT fall back to full price purchase.
      // This prevents accidentally overcharging users who expect a discount.
      return _createFailedResult(
        'Offer "$offerId" not found for product "$productId". Purchase aborted.',
      );
    }

    log('[RevenueCat] Purchasing with offer: ${subscriptionOption.id}');
    final customerInfo =
        await Purchases.purchaseSubscriptionOption(subscriptionOption);

    return _evaluatePurchaseResult(customerInfo);
  }



  /// Fetches a product directly by ID.
  Future<StoreProduct?> _fetchProduct(String productId) async {
    final products = await Purchases.getProducts([productId]);
    return products.isNotEmpty ? products.first : null;
  }

  /// Finds a subscription option matching the offer ID.
  ///
  /// Matching strategy (in order of precedence):
  /// 1. Exact match on option.id
  /// 2. EndsWith match (RevenueCat may prefix IDs as `productId:basePlan:offerId`)
  SubscriptionOption? _findSubscriptionOption(
    StoreProduct product,
    String offerId,
  ) {
    final options = product.subscriptionOptions;
    if (options == null || options.isEmpty) {
      return null;
    }

    // Priority 1: Exact match
    for (final option in options) {
      if (option.id == offerId) {
        return option;
      }
    }

    // Priority 2: EndsWith match (safer than contains)
    // This handles RevenueCat's prefixed format: productId:basePlan:offerId
    for (final option in options) {
      if (option.id.endsWith(':$offerId')) {
        return option;
      }
    }

    return null;
  }

  /// Evaluates customer info to determine purchase result.
  HeliumPurchaseResult _evaluatePurchaseResult(CustomerInfo customerInfo) {
    if (customerInfo.entitlements.active.isNotEmpty) {
      return HeliumPurchaseResult(status: HeliumTransactionStatus.purchased);
    }
    return HeliumPurchaseResult(status: HeliumTransactionStatus.failed);
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
