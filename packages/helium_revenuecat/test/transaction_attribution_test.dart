import 'package:flutter_test/flutter_test.dart';
import 'package:helium_revenuecat/src/revenue_cat_purchase_delegate.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  final tappedAt = DateTime.utc(2026, 1, 10, 12, 0, 0, 400);

  StoreTransaction transaction({String id = 'txn_1', required String purchaseDate}) =>
      StoreTransaction(id, 'monthly', purchaseDate);

  test('a transaction made after the tap is reported', () {
    expect(
      transactionIdMadeSince(transaction(purchaseDate: '2026-01-10T12:00:05Z'), tappedAt),
      'txn_1',
    );
  });

  test('an existing transaction returned by a deferred plan change is left out', () {
    expect(
      transactionIdMadeSince(transaction(purchaseDate: '2025-12-01T09:30:00Z'), tappedAt),
      isNull,
    );
  });

  test('a transaction dated in the same second as the tap is reported', () {
    expect(
      transactionIdMadeSince(transaction(purchaseDate: '2026-01-10T12:00:00Z'), tappedAt),
      'txn_1',
    );
  });

  test('a transaction without a readable date is left out', () {
    expect(transactionIdMadeSince(transaction(purchaseDate: ''), tappedAt), isNull);
  });

  test('a transaction without an ID is left out', () {
    expect(
      transactionIdMadeSince(transaction(id: '', purchaseDate: '2026-01-10T12:00:05Z'), tappedAt),
      isNull,
    );
  });
}
