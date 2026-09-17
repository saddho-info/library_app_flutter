import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:library_app/core/db/app_database.dart';
import 'package:library_app/core/db/offline_models.dart';
import 'package:library_app/core/db/offline_repository.dart';
import 'package:library_app/core/db/sync_status.dart';
import 'package:library_app/features/scan/domain/book_copy.dart';

void main() {
  late Directory directory;
  late AppDatabase database;
  late HiveOfflineRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pubtrack_hive_test_');
    Hive.init(directory.path);
    database = await AppDatabase.openForTesting();
    repository = HiveOfflineRepository(database);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('stores a pending sale and updates its sync lifecycle', () async {
    final now = DateTime.utc(2026, 9, 16);
    final item = LocalSaleItem(
      id: 'item-1',
      localSaleId: 'sale-1',
      editionId: 'edition-1',
      copyId: 'copy-1',
      unitPriceCents: 1599,
      createdAt: now,
      titleSnapshot: 'Offline Book',
    );
    final sale = LocalSale(
      id: 'sale-1',
      libraryId: 'library-1',
      code: 'LOCAL-1',
      currency: 'USD',
      totalCents: 1599,
      actorUserId: 'user-1',
      soldAt: now,
      createdAt: now,
      updatedAt: now,
      idempotencyKey: 'key-1',
      request: const {
        'items': [
          {'copyId': 'copy-1'},
        ],
      },
      items: [item],
    );

    await repository.saveSale(sale);
    expect(
      (await repository.getSales(status: LocalSyncStatus.pending)).single.items,
      hasLength(1),
    );

    await repository.markSaleFailed(
      sale.id,
      code: 'STALE_DATA',
      message: 'Refresh required',
    );
    final failed = await repository.getSale(sale.id);
    expect(failed?.syncStatus, LocalSyncStatus.failed);
    expect(failed?.retryCount, 1);

    await repository.markSaleSynced(sale.id, serverId: 'server-sale-1');
    final synced = await repository.getSale(sale.id);
    expect(synced?.syncStatus, LocalSyncStatus.synced);
    expect(synced?.serverId, 'server-sale-1');
    expect(synced?.syncErrorCode, isNull);
  });

  test('stores a pending receipt and updates its sync lifecycle', () async {
    final now = DateTime.utc(2026, 9, 16);
    final receipt = LocalReceipt(
      id: 'receipt-1',
      libraryId: 'library-1',
      actorUserId: 'user-1',
      idempotencyKey: 'receipt-key-1',
      createdAt: now,
      updatedAt: now,
      request: const {
        'distributionId': 'distribution-1',
        'confirm': true,
        'items': [
          {'copyId': 'copy-1', 'received': true, 'discrepancy': 'NONE'},
        ],
      },
    );

    await repository.saveReceipt(receipt);
    expect(
      (await repository.getReceipts(status: LocalSyncStatus.pending)).single.id,
      receipt.id,
    );

    await repository.markReceiptFailed(
      receipt.id,
      code: 'STALE_DATA',
      message: 'Refresh required',
    );
    var stored =
        (await repository.getReceipts(status: LocalSyncStatus.failed)).single;
    expect(stored.retryCount, 1);

    await repository.markReceiptSynced(
      receipt.id,
      serverId: 'server-receipt-1',
    );
    stored =
        (await repository.getReceipts(status: LocalSyncStatus.synced)).single;
    expect(stored.serverId, 'server-receipt-1');
    expect(stored.syncErrorCode, isNull);
  });

  test('caches copies by id and QR token', () async {
    final now = DateTime.utc(2026, 9, 16);
    final copy = BookCopy(
      id: 'copy-1',
      editionId: 'edition-1',
      publisherId: 'publisher-1',
      libraryId: 'library-1',
      status: 'IN_STOCK_LIBRARY',
      copyNumber: 12,
      createdAt: now,
      updatedAt: now,
      qrToken: 'opaque-token',
    );

    await repository.cacheCopy(copy);

    expect((await repository.getCachedCopy('copy-1'))?.id, copy.id);
    expect(
      (await repository.getCachedCopyByQr('opaque-token'))?.copyNumber,
      12,
    );
  });

  test('upserts and scopes inventory snapshots', () async {
    final now = DateTime.utc(2026, 9, 16);
    final snapshot = InventorySnapshot(
      id: 'inventory-1',
      editionId: 'edition-1',
      holderType: 'LIBRARY',
      holderId: 'library-1',
      onHand: 5,
      inTransit: 1,
      sold: 2,
      returned: 0,
      lost: 0,
      lowStockThreshold: 3,
      version: 4,
      serverUpdatedAt: now,
      cachedAt: now,
    );

    await repository.cacheInventory(snapshot);

    final stored = await repository.getInventory(
      editionId: 'edition-1',
      holderType: 'LIBRARY',
      holderId: 'library-1',
    );
    expect(stored?.onHand, 5);
    expect(
      await repository.getInventoryForHolder(
        holderType: 'LIBRARY',
        holderId: 'library-1',
      ),
      hasLength(1),
    );
  });
}
