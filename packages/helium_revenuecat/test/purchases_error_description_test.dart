import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helium_revenuecat/src/purchases_error_description.dart';

void main() {
  test('includes the RevenueCat code and the underlying store message', () {
    final e = PlatformException(
      code: '4',
      message: 'One or more of the arguments provided are invalid.',
      details: {
        'code': 4,
        'message': 'One or more of the arguments provided are invalid.',
        'readableErrorCode': 'PurchaseInvalidError',
        'underlyingErrorMessage': 'DEVELOPER_ERROR: Please ensure the app is signed correctly',
      },
    );

    expect(
      describePurchasesError(e),
      'One or more of the arguments provided are invalid. code: 4 | DEVELOPER_ERROR: Please ensure the app is signed correctly',
    );
  });

  test('omits the underlying message when RevenueCat reports none', () {
    final e = PlatformException(
      code: '2',
      message: 'There was a problem with the store.',
      details: {'underlyingErrorMessage': ''},
    );

    expect(describePurchasesError(e), 'There was a problem with the store. code: 2');
  });

  test('falls back when the exception carries no message or details', () {
    final e = PlatformException(code: '0');

    expect(describePurchasesError(e), 'Unknown error code: 0');
  });
}
