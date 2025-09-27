import 'package:helium_flutter/types/helium_transaction_status.dart';
import 'package:helium_flutter/types/helium_types.dart';

abstract class HeliumPurchaseDelegate {
  Future<HeliumPurchaseResult> makePurchase(String productId);

  Future<bool> restorePurchases();
}

abstract class HeliumCallbacks {
  Future<void> onPaywallEvent(HeliumPaywallEvent heliumPaywallEvent);
}

class HeliumPurchaseResult {
  final HeliumTransactionStatus status;
  final String? error;

  HeliumPurchaseResult({
    required this.status,
    this.error,
  });
}
