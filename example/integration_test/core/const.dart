import 'dart:developer';

import 'package:helium_flutter/helium_flutter.dart';

class PaymentCallbacks implements HeliumCallbacks {
  @override
  Future<HeliumTransactionStatus> makePurchase(String productId) async {
    return Future.value(HeliumTransactionStatus.purchased);
  }

  @override
  Future<void> onPaywallEvent(Map<String, dynamic> heliumPaywallEvent) async {
    log('On paywall event');
  }

  @override
  Future<bool> restorePurchases(bool status) {
    return Future.value(true);
  }
}

class InitializeValue {
  final String apiKey;
  final HeliumCallbacks callbacks;
  final String customAPIEndpoint;
  final String customUserId;
  final Map<String, dynamic> customUserTraits;

  InitializeValue({
    required this.apiKey,
    required this.callbacks,
    required this.customAPIEndpoint,
    required this.customUserId,
    required this.customUserTraits,
  });
}
