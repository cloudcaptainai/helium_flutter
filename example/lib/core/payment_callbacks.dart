import 'dart:developer';

import 'package:helium_flutter/helium_flutter.dart';

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
