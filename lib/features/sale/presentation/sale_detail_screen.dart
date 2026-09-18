import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_app/core/theme/app_theme.dart';
import 'package:library_app/features/sale/data/sales_repository.dart';
import 'package:library_app/features/sale/domain/sale.dart';
import 'package:library_app/features/sale/presentation/sale_providers.dart';

class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSale = ref.watch(saleByIdProvider(saleId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale details'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/sales');
            }
          },
        ),
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
                    : 'Unable to load this sale.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(saleByIdProvider(saleId)),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (sale) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              sale.code,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              formatSaleDate(sale.soldAt),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    _DetailRow(label: 'Total', value: sale.totalLabel),
                    _DetailRow(label: 'Items', value: '${sale.itemCount}'),
                    if (sale.actor != null)
                      _DetailRow(
                        label: 'Sold by',
                        value: sale.actor!.displayName,
                      ),
                    if (sale.library != null)
                      _DetailRow(label: 'Library', value: sale.library!.name),
                    if (sale.notes != null && sale.notes!.isNotEmpty)
                      _DetailRow(label: 'Notes', value: sale.notes!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Line items',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...sale.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayTitle,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.authorsLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          [
                            if (item.copy != null)
                              'Copy #${item.copy!.copyNumber}',
                            if (item.edition != null) item.edition!.isbn,
                            item.priceLabel(sale.currency),
                          ].join(' · '),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.go('/scan'),
              child: const Text('Scan another'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
