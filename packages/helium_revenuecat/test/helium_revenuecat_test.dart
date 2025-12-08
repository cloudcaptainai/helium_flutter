import 'package:flutter_test/flutter_test.dart';
import 'package:helium_revenuecat/helium_revenuecat.dart';

void main() {
  test('RevenueCatPurchaseDelegate can be instantiated', () {
    final delegate = RevenueCatPurchaseDelegate();
    expect(delegate, isNotNull);
  });
}
