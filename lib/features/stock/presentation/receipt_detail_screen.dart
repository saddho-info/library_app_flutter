import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_app/features/stock/presentation/receiving_providers.dart';

class ReceiptDetailScreen extends ConsumerWidget {
  const ReceiptDetailScreen({required this.receiptId, super.key});
  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = ref.watch(receiptByIdProvider(receiptId));
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt complete')),
      body: receipt.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (value) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 72,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              value.code,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Copies received'),
                      trailing: Text('${value.receivedCount}'),
                    ),
                    ListTile(
                      title: const Text('Discrepancies'),
                      trailing: Text('${value.discrepancyCount}'),
                    ),
                    ListTile(
                      title: const Text('Status'),
                      trailing: Text(value.status),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/stock'),
              child: const Text('Back to stock'),
            ),
          ],
        ),
      ),
    );
  }
}
