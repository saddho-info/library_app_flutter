import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_app/core/db/db_providers.dart';
import 'package:library_app/core/db/offline_models.dart';
import 'package:library_app/core/db/sync_status.dart';
import 'package:library_app/core/theme/app_theme.dart';
import 'package:library_app/features/sync/presentation/sync_controller.dart';

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncControllerProvider);
    final sales = ref.watch(localSalesProvider);
    final receipts =
        ref.watch(localReceiptsProvider).valueOrNull ?? const <LocalReceipt>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync status'),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            onPressed: state.isOnline && !state.isSyncing
                ? () => ref.read(syncControllerProvider.notifier).syncNow()
                : null,
            icon: state.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: sales.when(
        loading: () => Center(
          child: Semantics(
            label: 'Loading sync queue',
            child: const CircularProgressIndicator(),
          ),
        ),
        error: (_, _) =>
            const Center(child: Text('Unable to read the local queue.')),
        data: (items) {
          final queueLength = items.length + receipts.length;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _ConnectionBanner(state: state),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _CountCard(
                            label: 'Pending',
                            value: state.pending,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CountCard(
                            label: 'Failed',
                            value: state.failed,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CountCard(
                            label: 'Synced',
                            value: state.synced,
                          ),
                        ),
                      ],
                    ),
                    if (state.message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.message!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'Offline transactions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (queueLength == 0)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No offline transactions on this device.',
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
              if (queueLength > 0)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index < items.length) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SaleSyncTile(sale: items[index]),
                        );
                      }
                      final receipt = receipts[index - items.length];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            leading: Icon(
                              receipt.syncStatus == LocalSyncStatus.synced
                                  ? Icons.check_circle_outline
                                  : receipt.syncStatus == LocalSyncStatus.failed
                                  ? Icons.error_outline
                                  : Icons.schedule,
                            ),
                            title: const Text('Stock receipt'),
                            subtitle: Text(
                              receipt.syncStatus == LocalSyncStatus.failed
                                  ? '${receipt.syncErrorCode ?? 'FAILED'} · ${receipt.syncErrorMessage ?? 'Needs attention'}'
                                  : receipt.syncStatus.storageValue,
                            ),
                            trailing:
                                receipt.syncStatus == LocalSyncStatus.failed
                                ? IconButton(
                                    tooltip: 'Retry',
                                    icon: const Icon(Icons.refresh),
                                    onPressed: () async {
                                      await ref
                                          .read(offlineRepositoryProvider)
                                          .markReceiptPending(receipt.id);
                                      await ref
                                          .read(syncControllerProvider.notifier)
                                          .syncNow();
                                    },
                                  )
                                : null,
                          ),
                        ),
                      );
                    }, childCount: queueLength),
                  ),
                ),
              if (state.failed > 0)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: FilledButton.tonal(
                      onPressed: state.isOnline && !state.isSyncing
                          ? () => ref
                                .read(syncControllerProvider.notifier)
                                .syncNow(retryFailed: true)
                          : null,
                      child: const Text('Retry failed items'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.state});
  final SyncState state;

  @override
  Widget build(BuildContext context) {
    final color = state.isOnline ? AppColors.success : AppColors.warning;
    return Card(
      child: ListTile(
        leading: Icon(
          state.isOnline ? Icons.cloud_done_outlined : Icons.cloud_off,
          color: color,
        ),
        title: Text(
          state.isSyncing
              ? 'Syncing…'
              : state.isOnline
              ? 'Online'
              : 'Offline',
        ),
        subtitle: Text(
          state.isOnline
              ? 'Pending transactions sync automatically.'
              : 'Transactions remain safely queued on this device.',
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text('$value', style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    ),
  );
}

class _SaleSyncTile extends ConsumerWidget {
  const _SaleSyncTile({required this.sale});
  final LocalSale sale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = sale.syncStatus == LocalSyncStatus.failed;
    return Card(
      child: ListTile(
        leading: Icon(
          sale.syncStatus == LocalSyncStatus.synced
              ? Icons.check_circle_outline
              : failed
              ? Icons.error_outline
              : Icons.schedule,
          color: sale.syncStatus == LocalSyncStatus.synced
              ? AppColors.success
              : failed
              ? AppColors.destructive
              : AppColors.warning,
        ),
        title: Text(sale.items.firstOrNull?.titleSnapshot ?? sale.code),
        subtitle: Text(
          failed
              ? '${sale.syncErrorCode ?? 'FAILED'} · ${sale.syncErrorMessage ?? 'Needs attention'}'
              : sale.syncStatus.storageValue,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: failed
            ? IconButton(
                tooltip: 'Retry',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref
                    .read(syncControllerProvider.notifier)
                    .retrySale(sale.id),
              )
            : null,
      ),
    );
  }
}
