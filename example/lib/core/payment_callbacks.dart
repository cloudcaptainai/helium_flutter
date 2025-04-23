import 'dart:developer';

import 'package:helium_flutter/helium_flutter.dart';

class PaymentCallbacks implements HeliumCallbacks {
  @override
  Future<HeliumTransactionStatus> makePurchase(String productId) async {
    log('makePurchase: $productId');
    return HeliumTransactionStatus.cancelled;
  }

  @override
  Future<void> onPaywallEvent(Map<String, dynamic> heliumPaywallEvent) async {
    log('onPaywallEvent: $heliumPaywallEvent');
  }

  @override
  Future<bool> restorePurchases(bool status) async {
    log('restorePurchases: $status');
    return status;
  }
}
