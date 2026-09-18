import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_app/core/theme/app_theme.dart';
import 'package:library_app/features/stock/data/receiving_repository.dart';
import 'package:library_app/features/stock/presentation/receiving_providers.dart';

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shipments = ref.watch(inboundShipmentsProvider);
    final summary = ref.watch(receiptSummaryProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Stock receiving')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(inboundShipmentsProvider);
          ref.invalidate(receiptSummaryProvider);
          await ref.read(inboundShipmentsProvider.future);
        },
        child: shipments.when(
          loading: () => Center(
            child: Semantics(
              label: 'Loading shipments',
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 80),
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(
                error is ReceivingException
                    ? error.message
                    : 'Unable to load shipments.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(inboundShipmentsProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
          data: (page) {
            if (page.data.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  if (summary != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '${summary.copiesReceived} copies received',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  const SizedBox(height: 64),
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 48,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No inbound shipments',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When a publisher dispatches stock to your library, '
                    'shipments appear here for review and receiving.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: page.data.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        summary == null
                            ? '${page.data.length} inbound shipments'
                            : '${page.data.length} inbound · '
                                  '${summary.copiesReceived} copies received',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  );
                }
                final shipment = page.data[index - 1];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text(shipment.code),
                    subtitle: Text(
                      '${shipment.publisherName} · '
                      '${shipment.inTransitCount} copies in transit',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/stock/${shipment.id}'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
