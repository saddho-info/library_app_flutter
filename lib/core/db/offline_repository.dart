import 'package:library_app/core/db/app_database.dart';
import 'package:library_app/core/db/offline_models.dart';
import 'package:library_app/core/db/sync_status.dart';
import 'package:library_app/features/scan/domain/book_copy.dart';

abstract class OfflineRepository {
  Future<void> saveSale(LocalSale sale);
  Future<LocalSale?> getSale(String id);
  Future<LocalSale?> getSaleByIdempotencyKey(String key);
  Future<List<LocalSale>> getSales({LocalSyncStatus? status, int? limit});
  Stream<List<LocalSale>> watchSales({LocalSyncStatus? status});
  Future<void> markSaleSynced(String id, {required String serverId});
  Future<void> markSaleFailed(
    String id, {
    required String code,
    required String message,
  });
  Future<void> markSalePending(String id);

  Future<void> cacheCopy(BookCopy copy);
  Future<BookCopy?> getCachedCopy(String id);
  Future<BookCopy?> getCachedCopyByQr(String qrToken);
  Future<void> removeCachedCopy(String id);

  Future<void> cacheInventory(InventorySnapshot snapshot);
  Future<InventorySnapshot?> getInventory({
    required String editionId,
    required String holderType,
    required String holderId,
  });
  Future<List<InventorySnapshot>> getInventoryForHolder({
    required String holderType,
    required String holderId,
  });
}

class HiveOfflineRepository implements OfflineRepository {
  HiveOfflineRepository(this._database);

  final AppDatabase _database;

  @override
  Future<void> saveSale(LocalSale sale) async {
    if (sale.items.isEmpty) {
      throw ArgumentError.value(sale.items, 'sale.items', 'Cannot be empty.');
    }
    final duplicate = await getSaleByIdempotencyKey(sale.idempotencyKey);
    if (duplicate != null && duplicate.id != sale.id) {
      throw StateError('The sale idempotency key is already stored.');
    }

    final oldSale = _database.sales.get(sale.id);
    final oldItems = <String, Object?>{
      for (final item in sale.items) item.id: _database.saleItems.get(item.id),
    };
    try {
      await _database.saleItems.putAll({
        for (final item in sale.items) item.id: item.toJson(),
      });
      // Write the header last so watchers never observe a sale without items.
      await _database.sales.put(sale.id, sale.toJson(includeItems: false));
    } catch (_) {
      if (oldSale == null) {
        await _database.sales.delete(sale.id);
      } else {
        await _database.sales.put(sale.id, oldSale);
      }
      for (final entry in oldItems.entries) {
        if (entry.value == null) {
          await _database.saleItems.delete(entry.key);
        } else {
          await _database.saleItems.put(entry.key, entry.value);
        }
      }
      rethrow;
    }
  }

  @override
  Future<LocalSale?> getSale(String id) async {
    final value = _database.sales.get(id);
    if (value == null) return null;
    final items = _database.saleItems.values
        .map(LocalSaleItem.fromJson)
        .where((item) => item.localSaleId == id)
        .toList(growable: false);
    return LocalSale.fromJson(value, items: items);
  }

  @override
  Future<LocalSale?> getSaleByIdempotencyKey(String key) async {
    for (final value in _database.sales.values) {
      final sale = LocalSale.fromJson(value);
      if (sale.idempotencyKey == key) return getSale(sale.id);
    }
    return null;
  }

  @override
  Future<List<LocalSale>> getSales({
    LocalSyncStatus? status,
    int? limit,
  }) async {
    final sales = <LocalSale>[];
    for (final value in _database.sales.values) {
      final header = LocalSale.fromJson(value);
      if (status == null || header.syncStatus == status) {
        final sale = await getSale(header.id);
        if (sale != null) sales.add(sale);
      }
    }
    sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (limit != null && sales.length > limit) {
      return sales.sublist(0, limit);
    }
    return sales;
  }

  @override
  Stream<List<LocalSale>> watchSales({LocalSyncStatus? status}) async* {
    yield await getSales(status: status);
    await for (final _ in _database.sales.watch()) {
      yield await getSales(status: status);
    }
  }

  @override
  Future<void> markSaleSynced(String id, {required String serverId}) =>
      _updateSale(
        id,
        (sale) => sale.copyWith(
          serverId: serverId,
          syncStatus: LocalSyncStatus.synced,
          updatedAt: DateTime.now().toUtc(),
          clearError: true,
        ),
      );

  @override
  Future<void> markSaleFailed(
    String id, {
    required String code,
    required String message,
  }) => _updateSale(
    id,
    (sale) => sale.copyWith(
      syncStatus: LocalSyncStatus.failed,
      syncErrorCode: code,
      syncErrorMessage: message,
      retryCount: sale.retryCount + 1,
      updatedAt: DateTime.now().toUtc(),
    ),
  );

  @override
  Future<void> markSalePending(String id) => _updateSale(
    id,
    (sale) => sale.copyWith(
      syncStatus: LocalSyncStatus.pending,
      updatedAt: DateTime.now().toUtc(),
      clearError: true,
    ),
  );

  Future<void> _updateSale(
    String id,
    LocalSale Function(LocalSale sale) update,
  ) async {
    final sale = await getSale(id);
    if (sale == null) throw StateError('Offline sale $id does not exist.');
    final updated = update(sale);
    await _database.sales.put(id, updated.toJson(includeItems: false));
  }

  @override
  Future<void> cacheCopy(BookCopy copy) =>
      _database.copyCache.put(copy.id, bookCopyToJson(copy));

  @override
  Future<BookCopy?> getCachedCopy(String id) async {
    final value = _database.copyCache.get(id);
    return value == null ? null : bookCopyFromStored(value);
  }

  @override
  Future<BookCopy?> getCachedCopyByQr(String qrToken) async {
    final token = qrToken.trim();
    for (final value in _database.copyCache.values) {
      final copy = bookCopyFromStored(value);
      if (copy.qrToken == token) return copy;
    }
    return null;
  }

  @override
  Future<void> removeCachedCopy(String id) => _database.copyCache.delete(id);

  @override
  Future<void> cacheInventory(InventorySnapshot snapshot) =>
      _database.inventorySnapshots.put(snapshot.storageKey, snapshot.toJson());

  @override
  Future<InventorySnapshot?> getInventory({
    required String editionId,
    required String holderType,
    required String holderId,
  }) async {
    final key = '$editionId::$holderType::$holderId';
    final value = _database.inventorySnapshots.get(key);
    return value == null ? null : InventorySnapshot.fromJson(value);
  }

  @override
  Future<List<InventorySnapshot>> getInventoryForHolder({
    required String holderType,
    required String holderId,
  }) async {
    return _database.inventorySnapshots.values
        .map(InventorySnapshot.fromJson)
        .where(
          (snapshot) =>
              snapshot.holderType == holderType &&
              snapshot.holderId == holderId,
        )
        .toList(growable: false);
  }
}
