import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_app/core/db/db_providers.dart';
import 'package:library_app/core/db/offline_models.dart';
import 'package:library_app/core/db/sync_status.dart';
import 'package:library_app/features/auth/presentation/auth_controller.dart';
import 'package:library_app/features/sync/data/sync_repository.dart';

class SyncState {
  const SyncState({
    this.pending = 0,
    this.failed = 0,
    this.synced = 0,
    this.isOnline = true,
    this.isSyncing = false,
    this.lastSyncedAt,
    this.message,
  });

  final int pending;
  final int failed;
  final int synced;
  final bool isOnline;
  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final String? message;

  SyncState copyWith({
    int? pending,
    int? failed,
    int? synced,
    bool? isOnline,
    bool? isSyncing,
    DateTime? lastSyncedAt,
    String? message,
    bool clearMessage = false,
  }) => SyncState(
    pending: pending ?? this.pending,
    failed: failed ?? this.failed,
    synced: synced ?? this.synced,
    isOnline: isOnline ?? this.isOnline,
    isSyncing: isSyncing ?? this.isSyncing,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    message: clearMessage ? null : message ?? this.message,
  );
}

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository(
    apiClient: ref.watch(apiClientProvider),
    offline: ref.watch(offlineRepositoryProvider),
  );
});

final localSalesProvider = StreamProvider<List<LocalSale>>((ref) {
  return ref.watch(offlineRepositoryProvider).watchSales();
});
final localReceiptsProvider = StreamProvider<List<LocalReceipt>>((ref) {
  return ref.watch(offlineRepositoryProvider).watchReceipts();
});

class SyncController extends Notifier<SyncState> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _retryTimer;
  int _networkFailures = 0;

  @override
  SyncState build() {
    ref.onDispose(() {
      _connectivitySubscription?.cancel();
      _retryTimer?.cancel();
    });
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _connectivityChanged,
    );
    ref.listen(localSalesProvider, (_, _) => _refreshCounts());
    ref.listen(localReceiptsProvider, (_, _) => _refreshCounts());
    Future.microtask(() async {
      final connectivity = await Connectivity().checkConnectivity();
      await _connectivityChanged(connectivity);
      await _refreshCounts();
    });
    return const SyncState();
  }

  Future<void> syncNow({bool retryFailed = false}) async {
    if (state.isSyncing || !state.isOnline) return;
    final user = ref.read(authProvider).valueOrNull;
    if (user?.libraryId == null) return;

    state = state.copyWith(isSyncing: true, clearMessage: true);
    try {
      final result = await ref
          .read(syncRepositoryProvider)
          .syncPending(includeFailed: retryFailed);
      _networkFailures = 0;
      _retryTimer?.cancel();
      state = state.copyWith(
        isSyncing: false,
        lastSyncedAt: DateTime.now(),
        message: result.failed > 0
            ? '${result.failed} item(s) need attention.'
            : result.attempted > 0
            ? '${result.synced} item(s) synced.'
            : 'Everything is up to date.',
      );
      await _refreshCounts();
    } on DioException {
      _networkFailures++;
      state = state.copyWith(
        isSyncing: false,
        message: 'Sync paused. The server could not be reached.',
      );
      _scheduleRetry();
    } catch (_) {
      state = state.copyWith(
        isSyncing: false,
        message: 'Sync failed unexpectedly. Try again.',
      );
    }
  }

  Future<void> retrySale(String id) async {
    await ref.read(offlineRepositoryProvider).markSalePending(id);
    await syncNow();
  }

  Future<void> _connectivityChanged(List<ConnectivityResult> results) async {
    final online = results.any((result) => result != ConnectivityResult.none);
    state = state.copyWith(isOnline: online);
    if (online) {
      await syncNow();
    } else {
      _retryTimer?.cancel();
    }
  }

  Future<void> _refreshCounts() async {
    final repository = ref.read(offlineRepositoryProvider);
    final values = await Future.wait([
      repository.getSales(status: LocalSyncStatus.pending),
      repository.getSales(status: LocalSyncStatus.failed),
      repository.getSales(status: LocalSyncStatus.synced),
      repository.getReceipts(status: LocalSyncStatus.pending),
      repository.getReceipts(status: LocalSyncStatus.failed),
      repository.getReceipts(status: LocalSyncStatus.synced),
    ]);
    state = state.copyWith(
      pending: values[0].length + values[3].length,
      failed: values[1].length + values[4].length,
      synced: values[2].length + values[5].length,
    );
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final seconds = (1 << (_networkFailures.clamp(1, 6) - 1)) * 5;
    _retryTimer = Timer(Duration(seconds: seconds), syncNow);
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);
