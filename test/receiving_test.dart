import 'package:flutter_test/flutter_test.dart';
import 'package:library_app/features/stock/domain/receiving.dart';

void main() {
  test('parses shipment and counts copies still in transit', () {
    final shipment = Shipment.fromJson({
      'id': 'dist-1',
      'code': 'DST-001',
      'status': 'PARTIALLY_RECEIVED',
      'publisher': {'name': 'Northwind Books'},
      'items': [
        {
          'id': 'item-1',
          'quantity': 2,
          'edition': {
            'isbn': '9780000000001',
            'format': 'PAPERBACK',
            'book': {'title': 'River of Ink', 'authors': 'A. Writer'},
          },
          'copies': [
            {'id': 'copy-1', 'copyNumber': 1, 'status': 'DISTRIBUTED'},
            {'id': 'copy-2', 'copyNumber': 2, 'status': 'IN_STOCK_LIBRARY'},
          ],
        },
      ],
    });

    expect(shipment.publisherName, 'Northwind Books');
    expect(shipment.items.single.edition.title, 'River of Ink');
    expect(shipment.inTransitCount, 1);
  });

  test('serializes discrepancy values expected by the API', () {
    expect(ReceiptDiscrepancy.none.apiValue, 'NONE');
    expect(ReceiptDiscrepancy.missing.apiValue, 'MISSING');
    expect(ReceiptDiscrepancy.damaged.apiValue, 'DAMAGED');
  });
}
