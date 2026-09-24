import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:library_app/core/db/db_providers.dart';
import 'package:library_app/core/db/offline_models.dart';
import 'package:library_app/core/db/offline_repository.dart';
import 'package:library_app/core/db/sync_status.dart';
import 'package:library_app/features/auth/domain/user.dart';
import 'package:library_app/features/auth/presentation/auth_controller.dart';
import 'package:library_app/features/sale/data/sales_repository.dart';
import 'package:library_app/features/sale/domain/sale.dart';
import 'package:library_app/features/sale/presentation/confirm_sale_screen.dart';
import 'package:library_app/features/sale/presentation/sale_providers.dart';
import 'package:library_app/features/scan/data/copies_repository.dart';
import 'package:library_app/features/scan/domain/book_copy.dart';
import 'package:library_app/features/scan/presentation/scan_providers.dart';

class _FakeCopiesRepository implements CopiesRepository {
  _FakeCopiesRepository(this.copy);

  final BookCopy copy;

  @override
  Future<BookCopy> findByQrToken(String token) async => copy;
}

class _SignedInAuth extends AuthNotifier {
  @override
  Future<AuthUser?> build() async {
    return const AuthUser(
      id: 'user_1',
      email: 'walt.e@example.net',
      firstName: 'Lib',
      lastName: 'Staff',
      role: 'LIBRARY_STAFF',
      libraryId: 'lib_1',
    );
  }
}

class _MemoryOfflineRepository implements OfflineRepository {
  LocalSale? sale;

  @override
  Future<void> saveSale(LocalSale sale) async {
    this.sale = sale;
  }

  @override
  Future<void> markSaleSynced(String id, {required String serverId}) async {}

  @override
  Future<void> markSaleFailed(
    String id, {
    required String code,
    required String message,
  }) async {}

  @override
  Future<LocalSale?> getSale(String id) async => sale;

  @override
  Future<LocalSale?> getSaleByIdempotencyKey(String key) async => null;

  @override
  Future<List<LocalSale>> getSales({
    LocalSyncStatus? status,
    int? limit,
  }) async => const [];

  @override
  Stream<List<LocalSale>> watchSales({LocalSyncStatus? status}) =>
      const Stream.empty();

  @override
  Future<void> markSalePending(String id) async {}

  @override
  Future<void> saveReceipt(LocalReceipt receipt) async {}

  @override
  Future<List<LocalReceipt>> getReceipts({LocalSyncStatus? status}) async =>
      const [];

  @override
  Stream<List<LocalReceipt>> watchReceipts() => const Stream.empty();

  @override
  Future<void> markReceiptSynced(String id, {required String serverId}) async {}

  @override
  Future<void> markReceiptFailed(
    String id, {
    required String code,
    required String message,
  }) async {}

  @override
  Future<void> markReceiptPending(String id) async {}

  @override
  Future<void> cacheCopy(BookCopy copy) async {}

  @override
  Future<BookCopy?> getCachedCopy(String id) async => null;

  @override
  Future<BookCopy?> getCachedCopyByQr(String qrToken) async => null;

  @override
  Future<void> removeCachedCopy(String id) async {}

  @override
  Future<void> cacheInventory(InventorySnapshot snapshot) async {}

  @override
  Future<InventorySnapshot?> getInventory({
    required String editionId,
    required String holderType,
    required String holderId,
  }) async => null;

  @override
  Future<List<InventorySnapshot>> getInventoryForHolder({
    required String holderType,
    required String holderId,
  }) async => const [];
}

class _FakeSalesRepository implements SalesRepository {
  CreateSaleRequest? lastRequest;
  Sale? result;
  SalesException? error;

  @override
  Future<Sale> createSale(CreateSaleRequest request) async {
    lastRequest = request;
    if (error != null) {
      throw error!;
    }
    return result!;
  }

  @override
  Future<Sale> getSale(String id) {
    throw UnimplementedError();
  }

  @override
  Future<SaleSummary> getSummary() {
    throw UnimplementedError();
  }

  @override
  Future<PaginatedSales> listSales({int page = 1, int limit = 20}) {
    throw UnimplementedError();
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

  final sampleSale = Sale.fromJson({
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
            'authors': 'A. Writer',
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
  });

  Widget buildApp({required SalesRepository sales, required BookCopy copy}) {
    final router = GoRouter(
      initialLocation: '/sales/confirm?token=tok',
      routes: [
        GoRoute(
          path: '/sales/confirm',
          builder: (context, state) => const ConfirmSaleScreen(qrToken: 'tok'),
        ),
        GoRoute(
          path: '/sales/completed/:saleId',
          builder: (context, state) => Scaffold(
            body: Text('completed:${state.pathParameters['saleId']}'),
          ),
        ),
        GoRoute(
          path: '/scan',
          builder: (context, state) => const Scaffold(body: Text('scan')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        copiesRepositoryProvider.overrideWithValue(_FakeCopiesRepository(copy)),
        salesRepositoryProvider.overrideWithValue(sales),
        authProvider.overrideWith(() => _SignedInAuth()),
        offlineRepositoryProvider.overrideWithValue(_MemoryOfflineRepository()),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('confirm sale screen shows copy and enables confirm', (
    tester,
  ) async {
    useTallSurface(tester);
    final sales = _FakeSalesRepository()..result = sampleSale;

    await tester.pumpWidget(buildApp(sales: sales, copy: sampleCopy));
    await tester.pumpAndSettle();

    expect(find.text('Silent Archive'), findsOneWidget);
    expect(find.text('Quantity'), findsOneWidget);
    expect(find.text('Discount'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    expect(find.text('Amount off'), findsOneWidget);
    expect(find.text('Discounted amount'), findsOneWidget);
    expect(find.text('BDT 20.00'), findsWidgets);
    expect(find.text('1'), findsWidgets);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm sale'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('shows already-sold error from API', (tester) async {
    useTallSurface(tester);
    final sales = _FakeSalesRepository()
      ..error = SalesException(
        'This copy has already been sold.',
        statusCode: 400,
        code: 'ALREADY_SOLD',
      );

    await tester.pumpWidget(buildApp(sales: sales, copy: sampleCopy));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm sale'));
    await tester.pumpAndSettle();

    expect(find.text('This copy has already been sold.'), findsOneWidget);
    expect(sales.lastRequest?.copyId, 'copy_1');
    expect(sales.lastRequest?.quantity, 1);
    expect(sales.lastRequest?.idempotencyKey, isNotEmpty);
  });

  testWidgets('navigates to completed screen on success', (tester) async {
    useTallSurface(tester);
    final sales = _FakeSalesRepository()..result = sampleSale;

    await tester.pumpWidget(buildApp(sales: sales, copy: sampleCopy));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm sale'));
    await tester.pumpAndSettle();

    expect(find.text('completed:sale_1'), findsOneWidget);
  });
}
