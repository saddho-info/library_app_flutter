import 'package:flutter_test/flutter_test.dart';
import 'package:library_app/features/sale/domain/sale.dart';

void main() {
  final sample = {
    'id': 'sale_1',
    'libraryId': 'lib_1',
    'code': 'S-20260101-001',
    'currency': 'USD',
    'totalCents': 2000,
    'notes': null,
    'actorUserId': 'user_1',
    'soldAt': '2026-01-01T12:00:00.000Z',
    'createdAt': '2026-01-01T12:00:00.000Z',
    'updatedAt': '2026-01-01T12:00:00.000Z',
    'idempotencyKey': 'key-1',
    'itemCount': 1,
    'library': {'id': 'lib_1', 'name': 'Central', 'slug': 'central'},
    'actor': {
      'id': 'user_1',
      'firstName': 'Lib',
      'lastName': 'Staff',
      'email': 'walt.e@example.net',
    },
    'items': [
      {
        'id': 'item_1',
        'saleId': 'sale_1',
        'editionId': 'ed_1',
        'copyId': 'copy_1',
        'unitPriceCents': 2000,
        'quantity': 1,
        'createdAt': '2026-01-01T12:00:00.000Z',
        'edition': {
          'id': 'ed_1',
          'isbn': '9780000000001',
          'format': 'HARDCOVER',
          'title': 'Silent Archive',
          'listPriceCents': 2000,
          'currency': 'USD',
          'book': {
            'id': 'book_1',
            'title': 'Silent Archive',
            'authors': 'A. Writer, Co Author',
            'slug': 'silent-archive',
            'publisherId': 'pub_1',
          },
        },
        'copy': {
          'id': 'copy_1',
          'copyNumber': 7,
          'status': 'SOLD',
          'publisherId': 'pub_1',
          'libraryId': 'lib_1',
        },
      },
    ],
  };

  test('parses sale payload including string authors', () {
    final sale = Sale.fromJson(sample);
    expect(sale.code, 'S-20260101-001');
    expect(sale.totalLabel, 'BDT 20.00');
    expect(sale.primaryTitle, 'Silent Archive');
    expect(sale.items.first.authorsLabel, 'A. Writer, Co Author');
    expect(sale.items.first.copy?.copyNumber, 7);
    expect(sale.actor?.displayName, 'Lib Staff');
  });

  test('parseMoneyToCents accepts dollar amounts', () {
    expect(parseMoneyToCents('24.99'), 2499);
    expect(parseMoneyToCents('\$10'), 1000);
    expect(parseMoneyToCents(''), isNull);
    expect(parseMoneyToCents('-1'), isNull);
  });

  test('applies amount and percentage discounts to the unit price', () {
    expect(
      discountedUnitPriceCents(
        unitPriceCents: 2000,
        type: SaleDiscountType.amount,
        value: 500,
      ),
      1500,
    );
    expect(
      discountedUnitPriceCents(
        unitPriceCents: 2000,
        type: SaleDiscountType.percent,
        value: 1000,
      ),
      1800,
    );
    expect(parsePercentToBasisPoints('12.5'), 1250);
    expect(parsePercentToBasisPoints('101'), isNull);
    expect(
      discountLabel(type: SaleDiscountType.amount, value: 250),
      'BDT 2.50',
    );
    expect(discountLabel(type: SaleDiscountType.percent, value: 1000), '10%');
  });
}
