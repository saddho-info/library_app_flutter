import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:library_app/core/db/app_database.dart';
import 'package:library_app/core/db/offline_models.dart';
import 'package:library_app/core/db/offline_repository.dart';
import 'package:library_app/core/db/sync_status.dart';
import 'package:library_app/core/network/api_client.dart';
import 'package:library_app/features/auth/data/token_storage.dart';
import 'package:library_app/features/sync/data/sync_repository.dart';

LocalSale _sale({
  required String id,
  required String key,
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime.utc(2026, 9, 16);
  return LocalSale(
    id: id,
    libraryId: 'library-1',
    code: 'LOCAL-$id',
    currency: 'USD',
    totalCents: 1599,
    actorUserId: 'user-1',
    soldAt: now,
    createdAt: now,
    updatedAt: now,
    idempotencyKey: key,
    request: const {
      'items': [
        {'copyId': 'copy-1'},
      ],
    },
    items: [
      LocalSaleItem(
        id: '$id-item',
        localSaleId: id,
        editionId: 'edition-1',
        copyId: 'copy-1',
        unitPriceCents: 1599,
        createdAt: now,
      ),
    ],
  );
}

void main() {
  late Directory directory;
  late AppDatabase database;
  late HiveOfflineRepository offline;
  late Dio dio;
  late SyncRepository sync;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pubtrack_sync_test_');
    Hive.init(directory.path);
    database = await AppDatabase.openForTesting();
    offline = HiveOfflineRepository(database);
    dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    sync = SyncRepository(
      apiClient: ApiClient(
        tokenStorage: MemoryTokenStorage(),
        dio: dio,
      ),
      offline: offline,
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('marks pending sales APPLIED and DUPLICATE as synced', () async {
    await offline.saveSale(_sale(id: 'sale-1', key: 'key-1'));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'results': [
                  {
                    'clientId': 'key-1',
                    'status': 'APPLIED',
                    'entity': {'id': 'server-sale-1'},
                  },
                ],
              },
            ),
          );
        },
      ),
    );

    final first = await sync.syncPending();
    expect(first.synced, 1);
    expect(first.failed, 0);
    expect(
      (await offline.getSale('sale-1'))?.syncStatus,
      LocalSyncStatus.synced,
    );
    expect((await offline.getSale('sale-1'))?.serverId, 'server-sale-1');

    await offline.saveSale(
      _sale(id: 'sale-2', key: 'key-2', createdAt: DateTime.utc(2026, 9, 17)),
    );
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'results': [
                  {
                    'clientId': 'key-2',
                    'status': 'DUPLICATE',
                    'entity': {'id': 'server-sale-2'},
                  },
                ],
              },
            ),
          );
        },
      ),
    );

    final second = await sync.syncPending();
    expect(second.synced, 1);
    expect(
      (await offline.getSale('sale-2'))?.syncStatus,
      LocalSyncStatus.synced,
    );
  });

  test('marks REJECTED sales as failed with conflict codes', () async {
    await offline.saveSale(_sale(id: 'sale-3', key: 'key-3'));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'results': [
                  {
                    'clientId': 'key-3',
                    'status': 'REJECTED',
                    'reason': 'ALREADY_SOLD',
                    'message': 'Copy already sold',
                  },
                ],
              },
            ),
          );
        },
      ),
    );

    final result = await sync.syncPending();
    expect(result.failed, 1);
    final failed = await offline.getSale('sale-3');
    expect(failed?.syncStatus, LocalSyncStatus.failed);
    expect(failed?.syncErrorCode, 'ALREADY_SOLD');
    expect(failed?.syncErrorMessage, 'Copy already sold');
  });

  test('returns zero when the offline queue is empty', () async {
    final result = await sync.syncPending();
    expect(result.attempted, 0);
    expect(result.synced, 0);
    expect(result.failed, 0);
  });
}
