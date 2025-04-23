import 'package:helium_flutter/types/helium_transaction_status.dart';

abstract class HeliumCallbacks {
  Future<HeliumTransactionStatus> makePurchase(String productId);

  Future<bool> restorePurchases(bool status);

  Future<void> onPaywallEvent(Map<String, dynamic> heliumPaywallEvent);
}
