import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_app/core/db/db_providers.dart';
import 'package:library_app/core/db/offline_models.dart';
import 'package:library_app/features/auth/presentation/auth_controller.dart';
import 'package:library_app/features/stock/data/receiving_repository.dart';
import 'package:library_app/features/stock/domain/receiving.dart';
import 'package:library_app/features/stock/presentation/receiving_providers.dart';
import 'package:uuid/uuid.dart';

class ReceiveShipmentScreen extends ConsumerStatefulWidget {
  const ReceiveShipmentScreen({required this.shipmentId, super.key});
  final String shipmentId;

  @override
  ConsumerState<ReceiveShipmentScreen> createState() =>
      _ReceiveShipmentScreenState();
}

class _ReceiveShipmentScreenState extends ConsumerState<ReceiveShipmentScreen> {
  int _step = 0;
  bool _submitting = false;
  String? _error;
  String? _initializedFor;
  final _notes = TextEditingController();
  final Map<String, bool> _received = {};
  final Map<String, ReceiptDiscrepancy> _discrepancies = {};

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _ensureInitialized(Shipment shipment) {
    if (_initializedFor == shipment.id) {
      return;
    }
    _initializedFor = shipment.id;
    _received.clear();
    _discrepancies.clear();
    for (final item in shipment.items) {
      for (final copy in item.copies.where((c) => c.status == 'DISTRIBUTED')) {
        _received[copy.id] = true;
        _discrepancies[copy.id] = ReceiptDiscrepancy.none;
      }
    }
  }

  Future<void> _confirm(Shipment shipment) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final copies = shipment.items
        .expand((item) => item.copies)
        .where((copy) => copy.status == 'DISTRIBUTED');
    final idempotencyKey = const Uuid().v4();
    final selections = [
      for (final copy in copies)
        ReceiptCopySelection(
          copyId: copy.id,
          received: _received[copy.id] ?? true,
          discrepancy: _discrepancies[copy.id] ?? ReceiptDiscrepancy.none,
        ),
    ];
    final user = ref.read(authProvider).valueOrNull;
    if (user?.libraryId == null) {
      setState(() {
        _submitting = false;
        _error = 'A library account is required.';
      });
      return;
    }
    final now = DateTime.now().toUtc();
    final localReceipt = LocalReceipt(
      id: idempotencyKey,
      libraryId: user!.libraryId!,
      actorUserId: user.id,
      idempotencyKey: idempotencyKey,
      createdAt: now,
      updatedAt: now,
      request: {
        'distributionId': shipment.id,
        'confirm': true,
        'items': [
          for (final item in selections)
            {
              'copyId': item.copyId,
              'received': item.received,
              'discrepancy': item.discrepancy.apiValue,
            },
        ],
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      },
    );
    await ref.read(offlineRepositoryProvider).saveReceipt(localReceipt);
    try {
      final receipt = await ref
          .read(receivingRepositoryProvider)
          .confirmShipment(
            distributionId: shipment.id,
            idempotencyKey: idempotencyKey,
            items: selections,
            notes: _notes.text,
          );
      await ref
          .read(offlineRepositoryProvider)
          .markReceiptSynced(localReceipt.id, serverId: receipt.id);
      ref.invalidate(inboundShipmentsProvider);
      ref.invalidate(receiptSummaryProvider);
      if (mounted) context.go('/stock/receipts/${receipt.id}');
    } on ReceivingException catch (error) {
      if (error.statusCode == null) {
        if (mounted) context.go('/more/sync');
      } else {
        await ref
            .read(offlineRepositoryProvider)
            .markReceiptFailed(
              localReceipt.id,
              code: error.code ?? 'REJECTED',
              message: error.message,
            );
        if (mounted) setState(() => _error = error.message);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncShipment = ref.watch(shipmentByIdProvider(widget.shipmentId));
    // Avoid InkWell paint crashes inside Stepper's shrink-wrap viewport during
    // shell/route transitions (layoutOffset can be null mid-animation).
    final noSplashTheme = Theme.of(context).copyWith(
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
    );
    return Theme(
      data: noSplashTheme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Receive shipment')),
        body: asyncShipment.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (shipment) {
            _ensureInitialized(shipment);
            final rows = <({ShipmentCopy copy, ShipmentItem item})>[
              for (final item in shipment.items)
                for (final copy in item.copies.where(
                  (copy) => copy.status == 'DISTRIBUTED',
                ))
                  (copy: copy, item: item),
            ];
            final receivedCount = rows
                .where((row) => _received[row.copy.id] ?? true)
                .length;
            return Stepper(
              currentStep: _step,
              onStepTapped: (value) => setState(() => _step = value),
              controlsBuilder: (context, details) => Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: _submitting ? null : details.onStepCancel,
                        child: const Text('Back'),
                      ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _submitting
                          ? null
                          : _step == 2
                          ? (receivedCount == 0
                                ? null
                                : () => _confirm(shipment))
                          : details.onStepContinue,
                      child: Text(
                        _step == 2
                            ? (_submitting ? 'Confirming…' : 'Confirm receipt')
                            : 'Continue',
                      ),
                    ),
                  ],
                ),
              ),
              onStepContinue: () {
                if (_step < 2) setState(() => _step++);
              },
              onStepCancel: () {
                if (_step > 0) setState(() => _step--);
              },
              steps: [
                Step(
                  title: const Text('Review'),
                  isActive: _step >= 0,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shipment ${shipment.code}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text('From ${shipment.publisherName}'),
                      if (shipment.notes?.isNotEmpty == true)
                        Text(shipment.notes!),
                      const SizedBox(height: 12),
                      for (final item in shipment.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.edition.title),
                                    Text(
                                      '${item.edition.format} · ${item.edition.isbn}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Text('${item.quantity} expected'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Verify'),
                  isActive: _step >= 1,
                  content: Column(
                    children: [
                      for (final row in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _received[row.copy.id] ?? true,
                                        onChanged: (value) => setState(
                                          () => _received[row.copy.id] =
                                              value ?? false,
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '#${row.copy.copyNumber} · ${row.item.edition.title}',
                                            ),
                                            Text(
                                              row.item.edition.isbn,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<ReceiptDiscrepancy>(
                                    key: ValueKey('disc-${row.copy.id}'),
                                    initialValue:
                                        _discrepancies[row.copy.id] ??
                                        ReceiptDiscrepancy.none,
                                    decoration: const InputDecoration(
                                      labelText: 'Condition',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: ReceiptDiscrepancy.none,
                                        child: Text('As expected'),
                                      ),
                                      DropdownMenuItem(
                                        value: ReceiptDiscrepancy.missing,
                                        child: Text('Missing'),
                                      ),
                                      DropdownMenuItem(
                                        value: ReceiptDiscrepancy.damaged,
                                        child: Text('Damaged'),
                                      ),
                                    ],
                                    onChanged: (value) => setState(
                                      () => _discrepancies[row.copy.id] =
                                          value ?? ReceiptDiscrepancy.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Confirm'),
                  isActive: _step >= 2,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$receivedCount of ${rows.length} copies will move '
                        'to on-hand inventory.',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notes,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
