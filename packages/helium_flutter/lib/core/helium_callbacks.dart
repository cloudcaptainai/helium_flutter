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

  Future<bool> restorePurchases();
}

abstract class HeliumCallbacks {
  Future<void> onPaywallEvent(HeliumPaywallEvent heliumPaywallEvent);
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
