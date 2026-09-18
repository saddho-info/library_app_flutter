import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_app/core/theme/app_theme.dart';
import 'package:library_app/features/scan/data/copies_repository.dart';
import 'package:library_app/features/scan/domain/book_copy.dart';
import 'package:library_app/features/scan/presentation/scan_providers.dart';

class BookDetailsScreen extends ConsumerWidget {
  const BookDetailsScreen({super.key, required this.qrToken});

  final String qrToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCopy = ref.watch(copyByQrProvider(qrToken));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Copy details'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/scan');
            }
          },
        ),
      ),
      body: asyncCopy.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorPane(
          message: error is CopiesException
              ? error.message
              : 'Unable to load this copy.',
          onRetry: () => ref.invalidate(copyByQrProvider(qrToken)),
          onScanAnother: () => context.go('/scan'),
        ),
        data: (copy) => _CopyDetailsBody(copy: copy, qrToken: qrToken),
      ),
    );
  }
}

class _CopyDetailsBody extends StatelessWidget {
  const _CopyDetailsBody({required this.copy, required this.qrToken});

  final BookCopy copy;
  final String qrToken;

  Color _statusColor() {
    return switch (copy.status) {
      'IN_STOCK_LIBRARY' => AppColors.success,
      'SOLD' => AppColors.destructive,
      'DISTRIBUTED' => AppColors.warning,
      'LOST' => AppColors.destructive,
      _ => AppColors.info,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cover = copy.coverImageUrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cover != null && cover.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.network(
                  cover,
                  fit: BoxFit.cover,
                  cacheWidth: 600,
                  errorBuilder: (_, _, _) => const _CoverFallback(),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            const _CoverFallback(),
            const SizedBox(height: 20),
          ],
          Text(
            copy.displayTitle,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            copy.authorsLabel,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _statusColor().withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(
                  color: _statusColor().withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                copy.statusLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _statusColor(),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _DetailCard(
            children: [
              _DetailRow(label: 'Copy #', value: '${copy.copyNumber}'),
              _DetailRow(label: 'ISBN', value: copy.edition?.isbn ?? '—'),
              _DetailRow(label: 'Format', value: copy.edition?.format ?? '—'),
              _DetailRow(label: 'List price', value: copy.priceLabel),
              if (copy.library != null)
                _DetailRow(label: 'Library', value: copy.library!.name),
            ],
          ),
          const SizedBox(height: 24),
          if (!copy.isSellable)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                copy.status == 'SOLD'
                    ? 'This copy is already sold and cannot be sold again.'
                    : 'This copy is not in library stock yet, so it cannot be sold.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.warning),
              ),
            ),
          OutlinedButton(
            onPressed: () => context.go('/scan'),
            child: const Text('Scan another'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: copy.isSellable
                ? () {
                    final token = Uri.encodeComponent(
                      (copy.qrToken != null && copy.qrToken!.isNotEmpty)
                          ? copy.qrToken!
                          : qrToken,
                    );
                    context.go('/sales/confirm?token=$token');
                  }
                : null,
            child: Text(
              copy.isSellable ? 'Confirm sale' : 'Not available to sell',
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Icon(
          Icons.menu_book_outlined,
          size: 48,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(children: children),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
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

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({
    required this.message,
    required this.onRetry,
    required this.onScanAnother,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onScanAnother;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.destructive,
          ),
          const SizedBox(height: 16),
          Text(
            'Copy not found',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onScanAnother,
            child: const Text('Scan another'),
          ),
        ],
      ),
    );
  }
}
