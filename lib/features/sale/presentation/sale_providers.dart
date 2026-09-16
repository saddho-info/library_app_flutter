import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_app/features/auth/presentation/auth_controller.dart';
import 'package:library_app/features/sale/data/sales_repository.dart';
import 'package:library_app/features/sale/domain/sale.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return ApiSalesRepository(apiClient: ref.watch(apiClientProvider));
});

final salesListProvider =
    FutureProvider.autoDispose<PaginatedSales>((ref) {
  return ref.watch(salesRepositoryProvider).listSales();
});

final salesSummaryProvider = FutureProvider.autoDispose<SaleSummary>((ref) {
  return ref.watch(salesRepositoryProvider).getSummary();
});

final saleByIdProvider = FutureProvider.autoDispose.family<Sale, String>((
  ref,
  id,
) {
  return ref.watch(salesRepositoryProvider).getSale(id);
});
