import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_app/features/scan/data/copies_repository.dart';
import 'package:library_app/features/scan/domain/book_copy.dart';
import 'package:library_app/features/scan/presentation/book_details_screen.dart';
import 'package:library_app/features/scan/presentation/scan_providers.dart';

class _FakeCopiesRepository implements CopiesRepository {
  _FakeCopiesRepository(this._result);

  final Object _result;

  @override
  Future<BookCopy> findByQrToken(String token) async {
    final value = _result;
    if (value is BookCopy) {
      return value;
    }
    throw value as CopiesException;
  }
}

void main() {
  final sampleCopy = BookCopy.fromJson({
    'id': 'copy_1',
    'editionId': 'ed_1',
    'publisherId': 'pub_1',
    'libraryId': 'lib_1',
    'status': 'IN_STOCK_LIBRARY',
    'copyNumber': 7,
    'createdAt': '2026-01-01T00:00:00.000Z',
    'updatedAt': '2026-01-02T00:00:00.000Z',
    'qrToken': 'tok',
    'edition': {
      'id': 'ed_1',
      'isbn': '9780000000001',
      'format': 'HARDCOVER',
      'title': 'Silent Archive',
      'listPriceCents': 2000,
      'currency': 'USD',
      'coverImageUrl': null,
      'book': {
        'id': 'book_1',
        'title': 'Silent Archive',
        'authors': ['A. Writer'],
        'publisherId': 'pub_1',
        'slug': 'silent-archive',
        'coverImageUrl': null,
      },
    },
    'library': {'id': 'lib_1', 'name': 'Central', 'slug': 'central'},
  });

  testWidgets('shows book details after QR lookup', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          copiesRepositoryProvider.overrideWithValue(
            _FakeCopiesRepository(sampleCopy),
          ),
        ],
        child: const MaterialApp(home: BookDetailsScreen(qrToken: 'tok')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Silent Archive'), findsOneWidget);
    expect(find.text('A. Writer'), findsOneWidget);
    expect(find.text('In library stock'), findsOneWidget);
    expect(find.text('BDT 20.00'), findsOneWidget);
    expect(find.text('Scan another'), findsOneWidget);
    expect(find.text('Confirm sale'), findsOneWidget);
    expect(find.text('Quantity'), findsOneWidget);
    expect(find.text('Discount type'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Percentage'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('shows error when copy is missing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          copiesRepositoryProvider.overrideWithValue(
            _FakeCopiesRepository(
              CopiesException(
                'No copy found for this QR code.',
                statusCode: 404,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: BookDetailsScreen(qrToken: 'missing')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Copy not found'), findsOneWidget);
    expect(find.text('No copy found for this QR code.'), findsOneWidget);
  });
}
