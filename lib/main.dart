import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_app/core/db/app_database.dart';
import 'package:library_app/core/db/db_providers.dart';
import 'package:library_app/core/router/app_router.dart';
import 'package:library_app/core/theme/app_theme.dart';
import 'package:library_app/features/sync/presentation/sync_controller.dart';
import 'package:library_app/features/notifications/data/push_notification_service.dart';
import 'package:library_app/features/notifications/presentation/notifications_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.instance.initialize();
  final database = await AppDatabase.open();
  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const MainApp(),
    ),
  );
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    ref.watch(syncControllerProvider);
    ref.watch(pushRegistrationProvider);

    return MaterialApp.router(
      title: 'PubTrack Library',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
