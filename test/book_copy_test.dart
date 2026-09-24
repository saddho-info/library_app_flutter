import 'package:flutter_test/flutter_test.dart';
import 'package:library_app/features/scan/domain/book_copy.dart';

void main() {
  final sample = {
    'id': 'copy_1',
    'editionId': 'ed_1',
    'publisherId': 'pub_1',
    'libraryId': 'lib_1',
    'status': 'IN_STOCK_LIBRARY',
    'copyNumber': 42,
    'createdAt': '2026-01-01T00:00:00.000Z',
    'updatedAt': '2026-01-02T00:00:00.000Z',
    'qrToken': 'opaque-token',
    'edition': {
      'id': 'ed_1',
      'isbn': '9780000000001',
      'format': 'PAPERBACK',
      'title': 'River of Ink (PB)',
      'listPriceCents': 1599,
      'currency': 'USD',
      'coverImageUrl': null,
      'book': {
        'id': 'book_1',
        'title': 'River of Ink',
        'authors': ['N. Author', 'Co Writer'],
        'publisherId': 'pub_1',
        'slug': 'river-of-ink',
        'coverImageUrl': null,
      },
    },
    'library': {'id': 'lib_1', 'name': 'Central Library', 'slug': 'central'},
  };

  test('parses API copy payload for scan details', () {
    final copy = BookCopy.fromJson(sample);

    expect(copy.displayTitle, 'River of Ink (PB)');
    expect(copy.authorsLabel, 'N. Author, Co Writer');
    expect(copy.statusLabel, 'In library stock');
    expect(copy.isSellable, isTrue);
    expect(copy.priceLabel, 'BDT 15.99');
    expect(copy.copyNumber, 42);
    expect(copy.library?.name, 'Central Library');
  });

  test('parses comma-separated authors string from API', () {
    final copy = BookCopy.fromJson({
      ...sample,
      'edition': {
        ...(sample['edition'] as Map<String, dynamic>),
        'book': {
          'id': 'book_1',
          'title': 'River of Ink',
          'authors': 'N. Author, Co Writer',
          'publisherId': 'pub_1',
          'slug': 'river-of-ink',
          'coverImageUrl': null,
        },
      },
    });
    expect(copy.authorsLabel, 'N. Author, Co Writer');
  });
}
