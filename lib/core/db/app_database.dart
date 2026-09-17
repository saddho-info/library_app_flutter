import 'package:hive_flutter/hive_flutter.dart';

/// The local Hive database used by the offline repository.
///
/// Values are versioned JSON-like maps instead of generated adapters. This
/// keeps stored records forward-compatible when optional fields are added.
class AppDatabase {
  AppDatabase._({
    required this.sales,
    required this.saleItems,
    required this.copyCache,
    required this.inventorySnapshots,
    required this.receipts,
  });

  static const schemaVersion = 1;
  static const _salesBox = 'offline_sales_v1';
  static const _saleItemsBox = 'offline_sale_items_v1';
  static const _copyCacheBox = 'copy_cache_v1';
  static const _inventoryBox = 'inventory_snapshots_v1';
  static const _receiptsBox = 'offline_receipts_v1';

  final Box<dynamic> sales;
  final Box<dynamic> saleItems;
  final Box<dynamic> copyCache;
  final Box<dynamic> inventorySnapshots;
  final Box<dynamic> receipts;

  static Future<AppDatabase> open() async {
    await Hive.initFlutter('pubtrack_library');
    return _openBoxes();
  }

  /// Opens boxes after the caller has configured Hive with [Hive.init].
  static Future<AppDatabase> openForTesting() => _openBoxes();

  static Future<AppDatabase> _openBoxes() async {
    return AppDatabase._(
      sales: await Hive.openBox<dynamic>(_salesBox),
      saleItems: await Hive.openBox<dynamic>(_saleItemsBox),
      copyCache: await Hive.openBox<dynamic>(_copyCacheBox),
      inventorySnapshots: await Hive.openBox<dynamic>(_inventoryBox),
      receipts: await Hive.openBox<dynamic>(_receiptsBox),
    );
  }

  Future<void> clear() async {
    await Future.wait([
      sales.clear(),
      saleItems.clear(),
      copyCache.clear(),
      inventorySnapshots.clear(),
      receipts.clear(),
    ]);
  }

  Future<void> close() async {
    await Future.wait([
      sales.close(),
      saleItems.close(),
      copyCache.close(),
      inventorySnapshots.close(),
      receipts.close(),
    ]);
  }
}
