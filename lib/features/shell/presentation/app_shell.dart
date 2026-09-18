import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_app/core/theme/app_theme.dart';
import 'package:library_app/features/sync/presentation/sync_controller.dart';

/// Authenticated frame with bottom navigation: Home / Scan / Stock / Sales / More.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = <_ShellDestination>[
    _ShellDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _ShellDestination(
      label: 'Scan',
      icon: Icons.qr_code_scanner,
      selectedIcon: Icons.qr_code_scanner,
    ),
    _ShellDestination(
      label: 'Stock',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
    ),
    _ShellDestination(
      label: 'Sales',
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
    ),
    _ShellDestination(
      label: 'More',
      icon: Icons.more_horiz,
      selectedIcon: Icons.more_horiz,
    ),
  ];

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    final pendingTotal = sync.pending + sync.failed;
    final showBanner = !sync.isOnline || pendingTotal > 0;

    return Scaffold(
      body: Column(
        children: [
          if (showBanner)
            Material(
              color: sync.isOnline
                  ? AppColors.warning.withValues(alpha: 0.15)
                  : AppColors.destructive.withValues(alpha: 0.12),
              child: InkWell(
                onTap: () => context.go('/more/sync'),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          sync.isOnline
                              ? Icons.cloud_sync_outlined
                              : Icons.cloud_off,
                          size: 18,
                          color: sync.isOnline
                              ? AppColors.warning
                              : AppColors.destructive,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            sync.isOnline
                                ? '$pendingTotal offline ${pendingTotal == 1 ? 'item' : 'items'} waiting to sync'
                                : pendingTotal > 0
                                ? 'Offline · $pendingTotal queued for sync'
                                : 'You’re offline',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          'View',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: Material(
        color: AppColors.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1),
            NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              destinations: [
                for (var i = 0; i < _destinations.length; i++)
                  NavigationDestination(
                    icon: _NavIcon(
                      icon: _destinations[i].icon,
                      badgeCount: i == 4 ? pendingTotal : 0,
                    ),
                    selectedIcon: _NavIcon(
                      icon: _destinations[i].selectedIcon,
                      badgeCount: i == 4 ? pendingTotal : 0,
                    ),
                    label: _destinations[i].label,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.badgeCount});

  final IconData icon;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    if (badgeCount <= 0) {
      return Icon(icon);
    }
    return Badge(
      label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
      child: Icon(icon),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
