import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_app/features/auth/presentation/auth_controller.dart';
import 'package:library_app/features/stock/data/receiving_repository.dart';
import 'package:library_app/features/stock/domain/receiving.dart';

final receivingRepositoryProvider = Provider<ReceivingRepository>((ref) {
  return ApiReceivingRepository(apiClient: ref.watch(apiClientProvider));
});

final inboundShipmentsProvider = FutureProvider.autoDispose<PaginatedShipments>(
  (ref) {
    return ref.watch(receivingRepositoryProvider).listInbound();
  },
);

final receiptSummaryProvider = FutureProvider.autoDispose<ReceiptSummary>((
  ref,
) {
  return ref.watch(receivingRepositoryProvider).getSummary();
});

final shipmentByIdProvider = FutureProvider.autoDispose
    .family<Shipment, String>((ref, id) {
      return ref.watch(receivingRepositoryProvider).getShipment(id);
    });

final receiptByIdProvider = FutureProvider.autoDispose
    .family<StockReceipt, String>((ref, id) {
      return ref.watch(receivingRepositoryProvider).getReceipt(id);
    });
