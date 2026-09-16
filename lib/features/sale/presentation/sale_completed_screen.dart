import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_app/core/theme/app_theme.dart';
import 'package:library_app/features/sale/data/sales_repository.dart';
import 'package:library_app/features/sale/presentation/sale_providers.dart';

class SaleCompletedScreen extends ConsumerWidget {
  const SaleCompletedScreen({super.key, required this.saleId});

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSale = ref.watch(saleByIdProvider(saleId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale completed'),
        automaticallyImplyLeading: false,
      ),
      body: asyncSale.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                error is SalesException
                    ? error.message
                    : 'Sale recorded, but details could not be loaded.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/scan'),
                child: const Text('Scan another'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => context.go('/sales'),
                child: const Text('View sales'),
              ),
            ],
          ),
        ),
        data: (sale) {
          final item = sale.items.isNotEmpty ? sale.items.first : null;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    size: 40,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Sale recorded',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Inventory was updated and this copy is marked sold.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sale.code,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        if (item != null) ...[
                          Text(
                            item.displayTitle,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.authorsLabel,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.mutedForeground),
                          ),
                          if (item.copy != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Copy #${item.copy!.copyNumber}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.mutedForeground),
                            ),
                          ],
                          const SizedBox(height: 12),
                        ],
                        Text(
                          sale.totalLabel,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => context.go('/scan'),
                  child: const Text('Scan another'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.go('/sales/$saleId'),
                  child: const Text('View sale details'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/sales'),
                  child: const Text('All sales'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
