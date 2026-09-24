import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_app/core/theme/app_theme.dart';
import 'package:library_app/features/sale/data/sales_repository.dart';
import 'package:library_app/features/sale/domain/sale.dart';
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
          return LayoutBuilder(
            builder: (context, constraints) {
              final minHeight = (constraints.maxHeight - 48).clamp(
                0.0,
                double.infinity,
              );
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          Align(
                            child: Container(
                              width: 72,
                              height: 72,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_outline,
                                size: 40,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Sale recorded',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Inventory was updated and this copy is marked sold.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.mutedForeground),
                          ),
                          const SizedBox(height: 28),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _InfoRow(label: 'Sale', value: sale.code),
                                  _InfoRow(
                                    label: 'Sold',
                                    value: formatSaleDate(sale.soldAt),
                                  ),
                                  if (sale.library != null)
                                    _InfoRow(
                                      label: 'Library',
                                      value: sale.library!.name,
                                    ),
                                  if (sale.actor != null)
                                    _InfoRow(
                                      label: 'Sold by',
                                      value: sale.actor!.displayName,
                                    ),
                                  for (final line in sale.items) ...[
                                    const Divider(height: 20),
                                    Text(
                                      line.displayTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      line.authorsLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.mutedForeground,
                                          ),
                                    ),
                                    if (line.copy != null)
                                      _InfoRow(
                                        label: 'Copy',
                                        value: '#${line.copy!.copyNumber}',
                                      ),
                                    if (line.edition != null) ...[
                                      _InfoRow(
                                        label: 'ISBN',
                                        value: line.edition!.isbn,
                                      ),
                                      _InfoRow(
                                        label: 'Format',
                                        value: line.edition!.format,
                                      ),
                                    ],
                                    _InfoRow(
                                      label: 'Quantity',
                                      value: '${line.quantity}',
                                    ),
                                    ..._priceRows(line, sale.currency),
                                  ],
                                  if (sale.notes != null &&
                                      sale.notes!.trim().isNotEmpty)
                                    _InfoRow(
                                      label: 'Notes',
                                      value: sale.notes!,
                                    ),
                                  const Divider(height: 20),
                                  _InfoRow(
                                    label: 'Total',
                                    value: sale.totalLabel,
                                    emphasize: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

List<Widget> _priceRows(SaleItem item, String currency) {
  final listCents = item.edition?.listPriceCents;
  final charged = item.unitPriceCents;
  final discounted = listCents != null && charged < listCents;
  final lineTotal = charged * item.quantity;

  return [
    if (listCents != null)
      _InfoRow(label: 'List price', value: formatMoney(listCents, currency)),
    _InfoRow(
      label: discounted ? 'Discounted price' : 'Unit price',
      value: formatMoney(charged, currency),
    ),
    if (discounted)
      _InfoRow(
        label: 'Amount off',
        value: formatMoney((listCents - charged) * item.quantity, currency),
      ),
    if (item.quantity > 1)
      _InfoRow(label: 'Line total', value: formatMoney(lineTotal, currency)),
  ];
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final valueStyle = emphasize
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          )
        : Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value, textAlign: TextAlign.end, style: valueStyle),
          ),
        ],
      ),
    );
  }
}
