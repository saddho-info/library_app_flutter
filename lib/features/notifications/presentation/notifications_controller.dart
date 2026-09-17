import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_app/features/auth/presentation/auth_controller.dart';
import 'package:library_app/features/notifications/data/notifications_repository.dart';
import 'package:library_app/features/notifications/data/push_notification_service.dart';
import 'package:library_app/features/notifications/domain/app_notification.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});

class NotificationsNotifier
    extends AutoDisposeAsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() {
    return ref.read(notificationsRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(notificationsRepositoryProvider).list(),
    );
  }

  Future<void> markRead(AppNotification notification) async {
    if (!notification.isUnread) return;
    final previous = state.valueOrNull ?? const <AppNotification>[];
    state = AsyncData([
      for (final item in previous)
        if (item.id == notification.id) item.markRead() else item,
    ]);
    try {
      await ref.read(notificationsRepositoryProvider).markRead(notification.id);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

final notificationsProvider =
    AutoDisposeAsyncNotifierProvider<
      NotificationsNotifier,
      List<AppNotification>
    >(NotificationsNotifier.new);

final pushRegistrationProvider = Provider<void>((ref) {
  StreamSubscription<String>? tokenSubscription;
  String? registeredToken;

  Future<void> register() async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;
    final service = PushNotificationService.instance;
    final token = await service.requestPermissionAndGetToken();
    if (token == null) return;
    await ref.read(notificationsRepositoryProvider).registerDevice(token);
    registeredToken = token;
    tokenSubscription ??= service.tokenRefresh.listen((newToken) async {
      await ref.read(notificationsRepositoryProvider).registerDevice(newToken);
      registeredToken = newToken;
    });
  }

  ref.listen(authProvider, (_, next) {
    if (next.valueOrNull != null) {
      unawaited(register());
    } else if (registeredToken != null) {
      unawaited(
        ref
            .read(notificationsRepositoryProvider)
            .unregisterDevice(registeredToken!),
      );
      registeredToken = null;
    }
  }, fireImmediately: true);

  ref.onDispose(() => tokenSubscription?.cancel());
});
