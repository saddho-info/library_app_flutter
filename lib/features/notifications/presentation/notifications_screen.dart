import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_app/core/theme/app_theme.dart';
import 'package:library_app/features/notifications/domain/app_notification.dart';
import 'package:library_app/features/notifications/presentation/notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
        child: notifications.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 160),
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              Center(child: Text('Could not load notifications: $error')),
            ],
          ),
          data: (items) => items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 160),
                    Icon(Icons.notifications_none, size: 48),
                    SizedBox(height: 12),
                    Center(child: Text('No notifications yet')),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _NotificationTile(notification: items[index]),
                ),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.isUnread
              ? AppColors.secondary
              : AppColors.muted,
          child: Icon(
            notification.type == 'SALE_CREATED'
                ? Icons.point_of_sale
                : Icons.notifications_outlined,
            color: AppColors.primary,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isUnread
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        subtitle: Text(notification.body),
        trailing: notification.isUnread
            ? const Icon(Icons.circle, size: 10, color: AppColors.primary)
            : null,
        onTap: () async {
          try {
            await ref
                .read(notificationsProvider.notifier)
                .markRead(notification);
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not mark as read')),
              );
            }
          }
        },
      ),
    );
  }
}
