import 'package:flutter/services.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:developer';

class RevenueCatPurchaseDelegate implements HeliumPurchaseDelegate {
  @override
  Future<HeliumPurchaseResult> makePurchase(String productId) async {
    try {
      log('RevenueCat making purchase: $productId');
      final offerings = await Purchases.getOfferings();

      Package? packageToPurchase;

      // Search all offerings for package
      for (var offering in offerings.all.values) {
        for (var package in offering.availablePackages) {
          if (package.storeProduct.identifier == productId) {
            packageToPurchase = package;
            break;
          }
        }
        if (packageToPurchase != null) break;
      }

      CustomerInfo? customerInfo;
      if (packageToPurchase == null) {
        final fetchedProducts = await Purchases.getProducts([productId]);
        if (fetchedProducts.isEmpty) {
          return HeliumPurchaseResult(
              status: HeliumTransactionStatus.failed,
              error: 'Product not found in any offering and could not be retrieved: $productId'
          );
        } else {
          customerInfo = await Purchases.purchaseStoreProduct(fetchedProducts.first);
        }
      } else {
        customerInfo = await Purchases.purchasePackage(packageToPurchase);
      }

      // Check if the purchase was successful by looking at entitlements
      if (customerInfo.entitlements.active.isNotEmpty) {
        return HeliumPurchaseResult(status: HeliumTransactionStatus.purchased);
      } else {
        return HeliumPurchaseResult(status: HeliumTransactionStatus.failed);
      }
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return HeliumPurchaseResult(status: HeliumTransactionStatus.cancelled);
      } else if (errorCode == PurchasesErrorCode.paymentPendingError) {
        return HeliumPurchaseResult(status: HeliumTransactionStatus.pending);
      }
      return HeliumPurchaseResult(
        status: HeliumTransactionStatus.failed,
        error: 'RevenueCat purchase error: ${e.message ?? "Unknown error"}',
      );
    } catch(e) {
      return HeliumPurchaseResult(
        status: HeliumTransactionStatus.failed,
        error: 'RevenueCat purchase error: ${e.toString()}',
      );
    }
  }

  @override
  Future<HeliumPurchaseResult> makePurchaseAndroid(String productId,
      {String? basePlanId, String? offerId}) async {
    // For now, we delegate to the standard makePurchase.
    // Advanced subscription option handling can be added here if needed.
    return makePurchase(productId);
  }

  @override
  Future<HeliumPurchaseResult> makePurchaseIOS(String productId) async {
    return makePurchase(productId);
  }

  @override
  Future<bool> restorePurchases() async {
    try {
      log('RevenueCat restoring purchases');
      final restoredInfo = await Purchases.restorePurchases();
      return restoredInfo.entitlements.active.isNotEmpty;
    } catch (e) {
      log('RevenueCat restore error: $e');
      return false;
    }
  }
}
