import 'package:helium_flutter/types/helium_transaction_status.dart';
import 'package:helium_flutter/types/helium_types.dart';

abstract class HeliumPurchaseDelegate {
  /// Used to identify the purchase delegate type for analytics.
  String get delegateType => 'custom';

  @Deprecated('Use makePurchaseIOS / makePurchaseAndroid instead for platform-specific handling.')
  Future<HeliumPurchaseResult> makePurchase(String productId) async {
    return HeliumPurchaseResult(
      status: HeliumTransactionStatus.failed,
      error: 'makePurchase not implemented',
    );
  }

  Future<HeliumPurchaseResult> makePurchaseAndroid(String productId,
      {String? basePlanId, String? offerId}) async {
    // ignore: deprecated_member_use_from_same_package
    return makePurchase(productId);
  }

  Future<HeliumPurchaseResult> makePurchaseIOS(String productId) async {
    // ignore: deprecated_member_use_from_same_package
    return makePurchase(productId);
  }

  /// Whether this delegate applies App Store promotional offers on iOS.
  ///
  /// When `true`, paywalls show the paired promotional offer's pricing to
  /// eligible users, and purchases of a product paired with a promotional
  /// offer call [makePurchaseIOSWithPromoOffer]. When `false`, paywalls show
  /// the regular price and purchases call [makePurchaseIOS].
  bool get supportsPromotionalOffers => false;

  /// Purchase [productId] on iOS, applying the App Store promotional offer
  /// [promoOfferId] that is paired with the product in Helium.
  ///
  /// Only called when [supportsPromotionalOffers] is `true`.
  Future<HeliumPurchaseResult> makePurchaseIOSWithPromoOffer(
      String productId, String promoOfferId) async {
    return makePurchaseIOS(productId);
  }

  Future<bool> restorePurchases();
}

abstract class HeliumCallbacks {
  void onPaywallEvent(HeliumPaywallEvent heliumPaywallEvent);
}

class HeliumPurchaseResult {
  final HeliumTransactionStatus status;
  final String? error;
  final String? transactionId;
  final String? originalTransactionId;
  final String? productId;

  HeliumPurchaseResult({
    required this.status,
    this.error,
    this.transactionId,
    this.originalTransactionId,
    this.productId,
  });
}
