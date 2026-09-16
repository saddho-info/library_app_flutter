import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_app/core/db/app_database.dart';
import 'package:library_app/core/db/offline_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('AppDatabase must be initialized before ProviderScope.');
});

final offlineRepositoryProvider = Provider<OfflineRepository>((ref) {
  return HiveOfflineRepository(ref.watch(appDatabaseProvider));
});
