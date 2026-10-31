import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/inventory/batches/inventory_batches_providers.dart';
import 'package:afyakit/features/inventory/batches/inventory_batches_screen.dart';
import 'package:afyakit/features/inventory/locations/inventory_locations_providers.dart';

import 'inventory_delivery.dart';
import 'inventory_deliveries_providers.dart';

/// Review incoming stock, manage the current delivery session, and browse
/// finalized delivery records. Stock mutations remain API-owned.
class InventoryDeliveriesScreen extends ConsumerStatefulWidget {
  const InventoryDeliveriesScreen({super.key});

  @override
  ConsumerState<InventoryDeliveriesScreen> createState() =>
      _InventoryDeliveriesScreenState();
}

class _InventoryDeliveriesScreenState
    extends ConsumerState<InventoryDeliveriesScreen> {
  bool _starting = false;

  void _refresh() {
    ref.invalidate(inventoryOpenDeliverySessionProvider);
    ref.invalidate(inventoryDeliveriesProvider);
    ref.invalidate(inventoryLocationsProvider(null));
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorText(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] != null) {
        return data['error'].toString().replaceAll('-', ' ');
      }
      return error.message ?? 'The request could not be completed.';
    }
    return error.toString();
  }

  String _locationName(String storeId, Map<String, String> names) =>
      names[storeId] ?? 'Location unavailable';

  String _batchName(String? batchNumber) =>
      batchNumber?.trim().isNotEmpty == true
      ? batchNumber!.trim()
      : 'Batch number not specified';

  String _shortId(String id) =>
      id.length <= 12 ? id : '${id.substring(0, 12)}…';

  Future<void> _startDelivery() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final service = await ref.read(inventoryDeliveriesServiceProvider.future);
      await service.ensureSession();
      if (!mounted) return;
      _refresh();
      _notify('Delivery session ready. Add batches to continue.');
    } catch (error) {
      _notify('Could not start delivery: ${_errorText(error)}');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _addBatches() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const InventoryBatchesScreen()),
    );
    if (!mounted) return;
    ref.invalidate(inventoryBatchesProvider);
    _refresh();
  }

  Future<void> _reviewDelivery(
    String deliveryId,
    Map<String, String> names,
  ) async {
    try {
      final service = await ref.read(inventoryDeliveriesServiceProvider.future);
      final review = await service.review(deliveryId);
      if (!mounted) return;

      bool finalizing = false;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Review stock delivery'),
            content: SizedBox(
              width: 540,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${review.totalItems} ${review.totalItems == 1 ? 'batch' : 'batches'}'
                      ' • ${review.totalQuantity} units',
                      style: Theme.of(dialogContext).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Verify the batch details before finalizing this delivery.',
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: review.batches.isEmpty
                          ? const Center(child: Text('No batches added yet.'))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: review.batches.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, index) {
                                final batch = review.batches[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(batch.itemName),
                                  subtitle: Text(
                                    '${_batchName(batch.batchNumber)}\n'
                                    '${_locationName(batch.storeId, names)}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Text(
                                    '${batch.quantity} units',
                                    style: Theme.of(
                                      dialogContext,
                                    ).textTheme.labelLarge,
                                  ),
                                );
                              },
                            ),
                    ),
                    if (finalizing) const LinearProgressIndicator(),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: finalizing
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                onPressed: finalizing || review.batches.isEmpty
                    ? null
                    : () async {
                        setDialogState(() => finalizing = true);
                        try {
                          // The backend verifies session ownership and batch state.
                          await service.finalize(deliveryId);
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          if (!mounted) return;
                          ref.invalidate(inventoryBatchesProvider);
                          _refresh();
                          _notify('Delivery finalized successfully.');
                        } catch (error) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not finalize: ${_errorText(error)}',
                                ),
                              ),
                            );
                            setDialogState(() => finalizing = false);
                          }
                        }
                      },
                icon: const Icon(Icons.check_circle_outline),
                label: Text(finalizing ? 'Finalizing…' : 'Finalize delivery'),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      _notify('Could not load delivery review: ${_errorText(error)}');
    }
  }

  void _showDelivery(InventoryDelivery delivery, Map<String, String> names) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finalized delivery'),
        content: SizedBox(
          width: 540,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText('Delivery ID: ${delivery.deliveryId}'),
                const SizedBox(height: 8),
                Text(
                  '${delivery.totalItems} ${delivery.totalItems == 1 ? 'batch' : 'batches'}'
                  ' • ${delivery.totalQuantity} units',
                  style: Theme.of(dialogContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: delivery.batches.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final batch = delivery.batches[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(batch.itemName),
                        subtitle: Text(
                          '${_batchName(batch.batchNumber)}\n'
                          '${_locationName(batch.storeId, names)}',
                        ),
                        isThreeLine: true,
                        trailing: Text('${batch.quantity} units'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(inventoryOpenDeliverySessionProvider);
    final deliveries = ref.watch(inventoryDeliveriesProvider);
    final locations = ref.watch(inventoryLocationsProvider(null));
    final names = <String, String>{
      for (final location in locations.valueOrNull ?? [])
        location.id: location.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock deliveries'),
        actions: [
          IconButton(
            tooltip: 'Refresh deliveries',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await Future.wait([
            ref.read(inventoryOpenDeliverySessionProvider.future),
            ref.read(inventoryDeliveriesProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Current delivery', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: session.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  ),
                  error: (error, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Could not load the open delivery.'),
                      const SizedBox(height: 4),
                      Text(_errorText(error), style: theme.textTheme.bodySmall),
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                  data: (open) => open == null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.local_shipping_outlined),
                              title: Text('No open delivery'),
                              subtitle: Text(
                                'Start a delivery to receive new stock.',
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _starting ? null : _startDelivery,
                              icon: const Icon(Icons.add),
                              label: Text(
                                _starting ? 'Starting…' : 'Start delivery',
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.pending_actions_outlined,
                              ),
                              title: const Text('Delivery in progress'),
                              subtitle: Tooltip(
                                message: open.deliveryId,
                                child: Text(
                                  '${open.batchesCount} ${open.batchesCount == 1 ? 'batch' : 'batches'}'
                                  ' • ${open.status}\nID: ${_shortId(open.deliveryId)}',
                                ),
                              ),
                              isThreeLine: true,
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _addBatches,
                                  icon: const Icon(Icons.add_box_outlined),
                                  label: const Text('Add batches'),
                                ),
                                FilledButton.icon(
                                  onPressed: () =>
                                      _reviewDelivery(open.deliveryId, names),
                                  icon: const Icon(Icons.fact_check_outlined),
                                  label: const Text('Review & finalize'),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Finalized deliveries', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            deliveries.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Card(
                child: ListTile(
                  title: const Text('Could not load deliveries'),
                  subtitle: Text(_errorText(error)),
                  trailing: IconButton(
                    tooltip: 'Retry',
                    icon: const Icon(Icons.refresh),
                    onPressed: _refresh,
                  ),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Card(
                      child: ListTile(
                        leading: Icon(Icons.inventory_2_outlined),
                        title: Text('No finalized deliveries'),
                        subtitle: Text(
                          'Completed deliveries will appear here.',
                        ),
                      ),
                    )
                  : Card(
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < items.length;
                            index++
                          ) ...[
                            if (index > 0) const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.check_circle_outline),
                              title: Text(
                                'Delivery ${_shortId(items[index].deliveryId)}',
                              ),
                              subtitle: Text(
                                '${items[index].totalItems} '
                                '${items[index].totalItems == 1 ? 'batch' : 'batches'}'
                                ' • ${items[index].totalQuantity} units',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showDelivery(items[index], names),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
