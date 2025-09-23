import 'package:helium_flutter/types/helium_transaction_status.dart';
import 'package:helium_flutter/types/helium_types.dart';

abstract class HeliumCallbacks {
  Future<HeliumPurchaseResult> makePurchase(String productId);

  Future<bool> restorePurchases();

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
