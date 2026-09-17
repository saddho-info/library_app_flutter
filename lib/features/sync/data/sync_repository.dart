import 'package:dio/dio.dart';
import 'package:library_app/core/db/offline_models.dart';
import 'package:library_app/core/db/offline_repository.dart';
import 'package:library_app/core/db/sync_status.dart';
import 'package:library_app/core/network/api_client.dart';

class SyncRunResult {
  const SyncRunResult({
    required this.attempted,
    required this.synced,
    required this.failed,
  });

  final int attempted;
  final int synced;
  final int failed;
}

class SyncRepository {
  SyncRepository({
    required ApiClient apiClient,
    required OfflineRepository offline,
  }) : _api = apiClient,
       // Public constructor naming is clearer at call sites than `_offline`.
       // ignore: prefer_initializing_formals
       _offline = offline;

  final ApiClient _api;
  final OfflineRepository _offline;

  Future<SyncRunResult> syncPending({bool includeFailed = false}) async {
    final pending = await _offline.getSales(status: LocalSyncStatus.pending);
    final failed = includeFailed
        ? await _offline.getSales(status: LocalSyncStatus.failed)
        : const <LocalSale>[];
    final pendingReceipts = await _offline.getReceipts(
      status: LocalSyncStatus.pending,
    );
    final failedReceipts = includeFailed
        ? await _offline.getReceipts(status: LocalSyncStatus.failed)
        : const <LocalReceipt>[];
    final queue = [...pending, ...failed]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final receipts = [...pendingReceipts, ...failedReceipts]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (queue.isEmpty && receipts.isEmpty) {
      return const SyncRunResult(attempted: 0, synced: 0, failed: 0);
    }

    try {
      final response = await _api.raw.post<Map<String, dynamic>>(
        '/api/v1/sync/batch',
        data: {
          'transactions': [
            ...queue.map(_transaction),
            ...receipts.map(_receiptTransaction),
          ],
        },
      );
      final results = response.data?['results'];
      if (results is! List) {
        throw const FormatException('Sync response did not contain results.');
      }

      var synced = 0;
      var rejected = 0;
      for (final raw in results) {
        if (raw is! Map) continue;
        final clientId = raw['clientId']?.toString();
        if (clientId == null) continue;
        final sale = queue
            .where((item) => item.idempotencyKey == clientId)
            .firstOrNull;
        final receipt = receipts
            .where((item) => item.idempotencyKey == clientId)
            .firstOrNull;
        if (sale == null && receipt == null) continue;
        final status = raw['status']?.toString();
        if (status == 'APPLIED' || status == 'DUPLICATE') {
          final entity = raw['entity'];
          final serverId = entity is Map ? entity['id']?.toString() : null;
          if (sale != null) {
            await _offline.markSaleSynced(
              sale.id,
              serverId: serverId ?? sale.serverId ?? clientId,
            );
          } else {
            await _offline.markReceiptSynced(
              receipt!.id,
              serverId: serverId ?? receipt.serverId ?? clientId,
            );
          }
          synced++;
        } else {
          final code = raw['reason']?.toString() ?? 'SYNC_FAILED';
          final message =
              raw['message']?.toString() ??
              'The server rejected this transaction.';
          if (sale != null) {
            await _offline.markSaleFailed(
              sale.id,
              code: code,
              message: message,
            );
          } else {
            await _offline.markReceiptFailed(
              receipt!.id,
              code: code,
              message: message,
            );
          }
          rejected++;
        }
      }
      return SyncRunResult(
        attempted: queue.length + receipts.length,
        synced: synced,
        failed: rejected,
      );
    } on DioException {
      rethrow;
    }
  }

  Map<String, dynamic> _transaction(LocalSale sale) {
    final payload = Map<String, dynamic>.from(sale.request);
    payload['libraryId'] = sale.libraryId;
    payload['items'] ??= [
      for (final item in sale.items)
        {'copyId': item.copyId, 'unitPriceCents': item.unitPriceCents},
    ];
    return {
      'clientId': sale.idempotencyKey,
      'type': 'SALE',
      'payload': payload,
      if (payload['copyUpdatedAt'] is String)
        'copyUpdatedAt': payload['copyUpdatedAt'],
      if (payload['inventoryVersion'] is int)
        'inventoryVersion': payload['inventoryVersion'],
    };
  }

  Map<String, dynamic> _receiptTransaction(LocalReceipt receipt) => {
    'clientId': receipt.idempotencyKey,
    'type': 'STOCK_RECEIPT',
    'payload': {...receipt.request, 'libraryId': receipt.libraryId},
  };
}
