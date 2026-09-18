import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_app/core/theme/app_theme.dart';
import 'package:library_app/features/auth/presentation/auth_controller.dart';
import 'package:library_app/features/sync/presentation/sync_controller.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final sync = ref.watch(syncControllerProvider);
    final pendingTotal = sync.pending + sync.failed;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.primary,
                    child: Text(
                      (user?.firstName.isNotEmpty == true
                              ? user!.firstName[0]
                              : 'L')
                          .toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Library user',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                        if (user != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            user.role.replaceAll('_', ' '),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  subtitle: const Text('Alerts and sync messages'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/more/notifications'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync_outlined),
                  title: const Text('Sync status'),
                  subtitle: Text(
                    pendingTotal > 0
                        ? '$pendingTotal item${pendingTotal == 1 ? '' : 's'} need attention'
                        : 'Offline queue and sync issues',
                  ),
                  trailing: pendingTotal > 0
                      ? Badge(
                          label: Text('$pendingTotal'),
                          child: const Icon(Icons.chevron_right),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () => context.push('/more/sync'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
