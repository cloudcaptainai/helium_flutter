import 'package:flutter_test/flutter_test.dart';
import 'package:helium_revenuecat/helium_revenuecat.dart';

void main() {
  test('RevenueCatPurchaseDelegate can be instantiated', () {
    TestWidgetsFlutterBinding.ensureInitialized(); // both RC and Helium need this for bridging calls
    final delegate = RevenueCatPurchaseDelegate();
    expect(delegate, isNotNull);
  });
}
