import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_app/core/db/db_providers.dart';
import 'package:library_app/core/db/offline_models.dart';
import 'package:library_app/core/theme/app_theme.dart';
import 'package:library_app/features/auth/presentation/auth_controller.dart';
import 'package:library_app/features/sale/data/sales_repository.dart';
import 'package:library_app/features/sale/domain/sale.dart';
import 'package:library_app/features/sale/presentation/sale_providers.dart';
import 'package:library_app/features/scan/data/copies_repository.dart';
import 'package:library_app/features/scan/domain/book_copy.dart';
import 'package:library_app/features/scan/presentation/scan_providers.dart';
import 'package:uuid/uuid.dart';

class ConfirmSaleScreen extends ConsumerStatefulWidget {
  const ConfirmSaleScreen({
    super.key,
    this.qrToken,
    this.quantity = 1,
    this.discountType = SaleDiscountType.amount,
    this.discountValue = 0,
  });

  final String? qrToken;
  final int quantity;

  /// [discountValue] is cents when [discountType] is amount, and basis
  /// points (10000 = 100%) when it is a percentage.
  final SaleDiscountType discountType;
  final int discountValue;

  @override
  ConsumerState<ConfirmSaleScreen> createState() => _ConfirmSaleScreenState();
}

class _ConfirmSaleScreenState extends ConsumerState<ConfirmSaleScreen> {
  late final String _idempotencyKey;
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _priceSeeded = false;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = const Uuid().v4();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit(BookCopy copy) async {
    if (_submitting) {
      return;
    }

    final priceRaw = _priceController.text.trim();
    int? unitPriceCents;
    if (priceRaw.isNotEmpty) {
      unitPriceCents = parseMoneyToCents(priceRaw);
      if (unitPriceCents == null) {
        setState(() => _error = 'Enter a valid price like 24.99.');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final user = await ref.read(authProvider.future);
    if (user?.libraryId == null) {
      setState(() {
        _submitting = false;
        _error = 'A library account is required to record a sale.';
      });
      return;
    }
    final now = DateTime.now().toUtc();
    final listPrice = unitPriceCents ?? copy.edition?.listPriceCents ?? 0;
    final quantity = widget.quantity < 1 ? 1 : widget.quantity;
    final discountValue = widget.discountValue < 0 ? 0 : widget.discountValue;
    if (widget.discountType == SaleDiscountType.amount &&
        discountValue > listPrice) {
      setState(() {
        _submitting = false;
        _error = 'Discount amount cannot be more than the unit price.';
      });
      return;
    }
    final price = discountedUnitPriceCents(
      unitPriceCents: listPrice,
      type: widget.discountType,
      value: discountValue,
    );
    final localSale = LocalSale(
      id: _idempotencyKey,
      libraryId: user!.libraryId!,
      code: 'OFF-${_idempotencyKey.substring(0, 8).toUpperCase()}',
      currency: copy.edition?.currency ?? 'USD',
      totalCents: price * quantity,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      actorUserId: user.id,
      soldAt: now,
      createdAt: now,
      updatedAt: now,
      idempotencyKey: _idempotencyKey,
      request: {
        'libraryId': user.libraryId,
        'copyUpdatedAt': copy.updatedAt.toIso8601String(),
        'expectedCopyStatus': copy.status,
        'items': [
          {'copyId': copy.id, 'unitPriceCents': price, 'quantity': quantity},
        ],
      },
      items: [
        LocalSaleItem(
          id: '${_idempotencyKey}_0',
          localSaleId: _idempotencyKey,
          editionId: copy.editionId,
          copyId: copy.id,
          unitPriceCents: price,
          quantity: quantity,
          createdAt: now,
          titleSnapshot: copy.displayTitle,
          authorsSnapshot: copy.authorsLabel,
          isbnSnapshot: copy.edition?.isbn,
          copyNumberSnapshot: copy.copyNumber,
        ),
      ],
    );
    await ref.read(offlineRepositoryProvider).saveSale(localSale);

    try {
      final sale = await ref
          .read(salesRepositoryProvider)
          .createSale(
            CreateSaleRequest(
              idempotencyKey: _idempotencyKey,
              copyId: copy.id,
              unitPriceCents: price,
              quantity: quantity,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            ),
          );
      await ref
          .read(offlineRepositoryProvider)
          .markSaleSynced(localSale.id, serverId: sale.id);

      ref.invalidate(salesListProvider);
      ref.invalidate(salesSummaryProvider);
      ref.invalidate(copyByQrProvider(widget.qrToken?.trim() ?? ''));

      if (!mounted) {
        return;
      }
      context.go('/sales/completed/${sale.id}');
    } on SalesException catch (error) {
      if (error.statusCode != null) {
        await ref
            .read(offlineRepositoryProvider)
            .markSaleFailed(
              localSale.id,
              code: error.code ?? 'REJECTED',
              message: error.message,
            );
      } else {
        if (!mounted) return;
        context.go('/more/sync');
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = 'Unable to record this sale.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.qrToken?.trim() ?? '';
    if (token.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirm sale')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Scan a copy before confirming a sale.'),
          ),
        ),
      );
    }

    final asyncCopy = ref.watch(copyByQrProvider(token));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm sale'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/scan/copy?token=${Uri.encodeComponent(token)}');
            }
          },
        ),
      ),
      body: asyncCopy.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorBody(
          message: error is CopiesException
              ? error.message
              : 'Unable to load this copy.',
          onBack: () => context.go('/scan'),
        ),
        data: (copy) {
          if (!_priceSeeded) {
            _priceSeeded = true;
            final cents = copy.edition?.listPriceCents;
            if (cents != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                _priceController.text = (cents / 100).toStringAsFixed(2);
              });
            }
          }
          return _ConfirmBody(
            copy: copy,
            priceController: _priceController,
            notesController: _notesController,
            quantity: widget.quantity < 1 ? 1 : widget.quantity,
            discountType: widget.discountType,
            discountValue: widget.discountValue < 0 ? 0 : widget.discountValue,
            submitting: _submitting,
            error: _error,
            onSubmit: () => _submit(copy),
            onCancel: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/scan/copy?token=${Uri.encodeComponent(token)}');
              }
            },
          );
        },
      ),
    );
  }
}

class _ConfirmBody extends StatelessWidget {
  const _ConfirmBody({
    required this.copy,
    required this.priceController,
    required this.notesController,
    required this.quantity,
    required this.discountType,
    required this.discountValue,
    required this.submitting,
    required this.error,
    required this.onSubmit,
    required this.onCancel,
  });

  final BookCopy copy;
  final TextEditingController priceController;
  final TextEditingController notesController;
  final int quantity;
  final SaleDiscountType discountType;
  final int discountValue;
  final bool submitting;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final currency = copy.edition?.currency ?? 'USD';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
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
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ListenableBuilder(
              listenable: priceController,
              builder: (context, _) {
                final priced = _pricedLine(
                  rawPrice: priceController.text,
                  listPriceCents: copy.edition?.listPriceCents ?? 0,
                  quantity: quantity,
                  discountType: discountType,
                  discountValue: discountValue,
                );
                return Column(
                  children: [
                    _Row(label: 'Copy #', value: '${copy.copyNumber}'),
                    _Row(label: 'ISBN', value: copy.edition?.isbn ?? '—'),
                    _Row(label: 'Status', value: copy.statusLabel),
                    _Row(label: 'List price', value: copy.priceLabel),
                    _Row(label: 'Quantity', value: '$quantity'),
                    _Row(
                      label: 'Discount',
                      value: discountLabel(
                        type: discountType,
                        value: discountValue,
                        currency: currency,
                      ),
                    ),
                    _Row(
                      label: 'Amount off',
                      value: formatMoney(priced.amountOffCents, currency),
                    ),
                    _Row(
                      label: 'Discounted amount',
                      value: formatMoney(priced.discountedTotalCents, currency),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        if (!copy.isSellable) ...[
          const SizedBox(height: 16),
          Text(
            copy.status == 'SOLD'
                ? 'This copy is already sold and cannot be sold again.'
                : 'This copy is not in library stock yet, so it cannot be sold.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.warning),
          ),
        ],
        const SizedBox(height: 24),
        TextField(
          controller: priceController,
          enabled: copy.isSellable && !submitting,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Unit price ($currency)',
            hintText: '24.99',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: notesController,
          enabled: copy.isSellable && !submitting,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            hintText: 'Counter notes',
            alignLabelWithHint: true,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          Text(
            error!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.destructive),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: submitting ? null : onCancel,
          child: const Text('Cancel'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: copy.isSellable && !submitting ? onSubmit : null,
          child: submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirm sale'),
        ),
      ],
    );
  }
}

class _PricedLine {
  const _PricedLine({
    required this.amountOffCents,
    required this.discountedTotalCents,
  });

  final int amountOffCents;
  final int discountedTotalCents;
}

_PricedLine _pricedLine({
  required String rawPrice,
  required int listPriceCents,
  required int quantity,
  required SaleDiscountType discountType,
  required int discountValue,
}) {
  final parsed = parseMoneyToCents(rawPrice.trim());
  final unit = parsed ?? listPriceCents;
  final discounted = discountedUnitPriceCents(
    unitPriceCents: unit,
    type: discountType,
    value: discountValue,
  );
  final safeQuantity = quantity < 1 ? 1 : quantity;
  final off = unit - discounted;
  return _PricedLine(
    amountOffCents: (off < 0 ? 0 : off) * safeQuantity,
    discountedTotalCents: discounted * safeQuantity,
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

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

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

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
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onBack, child: const Text('Back to scan')),
        ],
      ),
    );
  }
}
