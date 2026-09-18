import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:library_app/core/db/app_database.dart';
import 'package:library_app/core/db/db_providers.dart';
import 'package:library_app/core/db/offline_models.dart';
import 'package:library_app/core/db/offline_repository.dart';
import 'package:library_app/core/db/sync_status.dart';
import 'package:library_app/core/network/api_client.dart';
import 'package:library_app/core/network/network_status.dart';
import 'package:library_app/features/auth/data/token_storage.dart';
import 'package:library_app/features/auth/domain/user.dart';
import 'package:library_app/features/auth/presentation/auth_controller.dart';
import 'package:library_app/features/sync/data/sync_repository.dart';
import 'package:library_app/features/sync/presentation/sync_controller.dart';

class _FakeNetworkStatus implements NetworkStatus {
  _FakeNetworkStatus({required bool online}) : _online = online;

  bool _online;
  final _controller = StreamController<bool>.broadcast();

  void setOnline(bool value) {
    _online = value;
    _controller.add(value);
  }

  @override
  Future<bool> get isOnline async => _online;

  @override
  Stream<bool> get onOnlineChanged => _controller.stream;

  Future<void> dispose() => _controller.close();
}

class _AuthStub extends AuthNotifier {
  _AuthStub(this.user);

  final AuthUser? user;

  @override
  Future<AuthUser?> build() async => user;
}

void main() {
  late Directory directory;
  late AppDatabase database;
  late HiveOfflineRepository offline;
  late Dio dio;
  late _FakeNetworkStatus network;
  late ProviderContainer container;
  var syncCalls = 0;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pubtrack_sync_ctrl_');
    Hive.init(directory.path);
    database = await AppDatabase.openForTesting();
    offline = HiveOfflineRepository(database);
    dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    network = _FakeNetworkStatus(online: false);
    syncCalls = 0;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          syncCalls++;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'results': [
                  {
                    'clientId': 'key-1',
                    'status': 'APPLIED',
                    'entity': {'id': 'server-1'},
                  },
                ],
              },
            ),
          );
        },
      ),
    );

    final now = DateTime.utc(2026, 9, 16);
    await offline.saveSale(
      LocalSale(
        id: 'sale-1',
        libraryId: 'library-1',
        code: 'LOCAL-1',
        currency: 'USD',
        totalCents: 1000,
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
        items: [
          LocalSaleItem(
            id: 'item-1',
            localSaleId: 'sale-1',
            editionId: 'edition-1',
            copyId: 'copy-1',
            unitPriceCents: 1000,
            createdAt: now,
          ),
        ],
      ),
    );

    final tokens = MemoryTokenStorage();
    final api = ApiClient(tokenStorage: tokens, dio: dio);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        offlineRepositoryProvider.overrideWithValue(offline),
        networkStatusProvider.overrideWithValue(network),
        tokenStorageProvider.overrideWithValue(tokens),
        apiClientProvider.overrideWithValue(api),
        syncRepositoryProvider.overrideWithValue(
          SyncRepository(apiClient: api, offline: offline),
        ),
        authProvider.overrideWith(
          () => _AuthStub(
            const AuthUser(
              id: 'user-1',
              email: 'lib@test.com',
              firstName: 'Lib',
              lastName: 'Admin',
              role: 'LIBRARY_ADMIN',
              libraryId: 'library-1',
            ),
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await network.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });

  test('stays offline until connectivity returns, then drains the queue', () async {
    container.read(syncControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(syncControllerProvider).isOnline, isFalse);
    expect(syncCalls, 0);

    network.setOnline(true);
    // Allow connectivity listener + syncNow to finish.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(container.read(syncControllerProvider).isOnline, isTrue);
    expect(syncCalls, greaterThan(0));
    expect(
      (await offline.getSale('sale-1'))?.syncStatus,
      LocalSyncStatus.synced,
    );
    expect(container.read(syncControllerProvider).pending, 0);
  });

  test('does not sync while offline even when syncNow is requested', () async {
    final controller = container.read(syncControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.syncNow();
    expect(syncCalls, 0);
    expect(container.read(syncControllerProvider).isOnline, isFalse);
  });
}
