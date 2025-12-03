import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:helium_flutter/helium_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class LogCallbacks implements HeliumCallbacks {
  @override
  Future<void> onPaywallEvent(HeliumPaywallEvent heliumPaywallEvent) async {
    log('onPaywallEvent: ${heliumPaywallEvent.type} - trigger: ${heliumPaywallEvent.triggerName}');
  }
}

class PaymentCallbacks extends HeliumPurchaseDelegate {
  @override
  Future<HeliumPurchaseResult> makePurchase(String productId) async {
    log('makePurchase: $productId');
    return HeliumPurchaseResult(status: HeliumTransactionStatus.cancelled);
  }

  @override
  Future<bool> restorePurchases() async {
    return true;
  }
}

class RevenueCatCallbacks extends HeliumPurchaseDelegate {
  @override
  Future<HeliumPurchaseResult> makePurchase(String productId) async {
    try {
      log('RevenueCat making purchase: $productId');
      final offerings = await Purchases.getOfferings();

      Package? packageToPurchase;

      // Find the package in current offering
      if (offerings.current != null) {
        for (var package in offerings.current!.availablePackages) {
          if (package.storeProduct.identifier == productId) {
            packageToPurchase = package;
            break;
          }
        }
      }

      // If not found in current, search all offerings
      if (packageToPurchase == null) {
        for (var offering in offerings.all.values) {
          for (var package in offering.availablePackages) {
            if (package.storeProduct.identifier == productId) {
              packageToPurchase = package;
              break;
            }
          }
          if (packageToPurchase != null) break;
        }
      }

      if (packageToPurchase == null) {
        return HeliumPurchaseResult(
          status: HeliumTransactionStatus.failed,
          error: 'Product not found in any offering: $productId',
        );
      }

      final customerInfo = await Purchases.purchasePackage(packageToPurchase);

      // Check if the purchase was successful by looking at entitlements
      if (customerInfo.entitlements.active.isNotEmpty) {
        return HeliumPurchaseResult(status: HeliumTransactionStatus.purchased);
      } else {
        return HeliumPurchaseResult(status: HeliumTransactionStatus.failed);
      }
    } catch (e) {
      if (e is PurchasesErrorCode) {
        if (e == PurchasesErrorCode.purchaseCancelledError) {
          return HeliumPurchaseResult(status: HeliumTransactionStatus.cancelled);
        } else if (e == PurchasesErrorCode.paymentPendingError) {
          return HeliumPurchaseResult(status: HeliumTransactionStatus.pending);
        }
      }
      return HeliumPurchaseResult(
          status: HeliumTransactionStatus.failed,
          error: 'RevenueCat purchase error: ${(e as PlatformException?)?.message ?? "Unknown error"}'
      );
    }
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
