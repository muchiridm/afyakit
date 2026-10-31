import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/inventory/batches/inventory_batches_providers.dart';
import 'package:afyakit/features/inventory/locations/inventory_locations_providers.dart';
import 'package:afyakit/features/inventory/records/issues/inventory_issue.dart';
import 'package:afyakit/features/inventory/records/issues/inventory_issues_providers.dart';
import 'inventory_cart_providers.dart';

/// Review staged batches and submit exactly one issue request.
class InventoryCartDrawer extends ConsumerStatefulWidget {
  const InventoryCartDrawer({
    super.key,
    this.initialType = InventoryIssueType.dispense,
  });
  final InventoryIssueType initialType;
  @override
  ConsumerState<InventoryCartDrawer> createState() =>
      _InventoryCartDrawerState();
}

class _InventoryCartDrawerState extends ConsumerState<InventoryCartDrawer> {
  late InventoryIssueType _type;
  String? _destination;
  final _note = TextEditingController();
  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(inventoryCartProvider.notifier);
    try {
      final fingerprint = jsonEncode([
        _type.name,
        _destination,
        _note.text.trim(),
      ]);
      controller.prepareSubmission(fingerprint);
      final cart = ref.read(inventoryCartProvider);
      final draft = cart.toDraft(
        type: _type,
        destinationStoreId: _destination,
        note: _note.text,
      );
      controller.beginSubmission();
      final service = await ref.read(inventoryIssuesServiceProvider.future);
      final result = await service.create(draft);
      if (!mounted) return;
      controller.submissionSucceeded();
      ref.invalidate(inventoryIssuesProvider);
      ref.invalidate(inventoryBatchesProvider(cart.storeId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Issue ${result.id} created. Approval/execution is separate.',
          ),
        ),
      );
      Navigator.of(context).maybePop();
    } catch (error) {
      // Do not discard the stable request_key on timeout or failed response.
      if (ref.read(inventoryCartProvider).isSubmitting)
        controller.submissionFailed();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(inventoryCartProvider);
    final storesAsync = ref.watch(inventoryLocationsProvider(null));
    final stores = storesAsync.valueOrNull ?? const [];
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Stock issue cart',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: cart.isSubmitting || cart.isEmpty
                        ? null
                        : () =>
                              ref.read(inventoryCartProvider.notifier).clear(),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Clear cart',
                  ),
                ],
              ),
              Text(
                cart.storeId == null
                    ? 'No source store'
                    : 'Source: ${stores.where((s) => s.id == cart.storeId).map((s) => s.name).firstOrNull ?? cart.storeId}',
              ),
              const SizedBox(height: 8),
              Expanded(
                child: cart.isEmpty
                    ? const Center(child: Text('No batches selected'))
                    : ListView(
                        children: cart.lines.values
                            .map(
                              (line) => ListTile(
                                title: Text('Item ${line.itemId}'),
                                subtitle: Text(
                                  'Batch ${line.batchId} • Available at selection: ${line.availableQuantity}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${line.quantity}'),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                      onPressed: cart.isSubmitting
                                          ? null
                                          : () => ref
                                                .read(
                                                  inventoryCartProvider
                                                      .notifier,
                                                )
                                                .remove(line.batchId),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
              DropdownButtonFormField<InventoryIssueType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Issue type'),
                items: InventoryIssueType.values
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type.name)),
                    )
                    .toList(),
                onChanged: cart.isSubmitting
                    ? null
                    : (type) => setState(() {
                        _type = type!;
                        _destination = null;
                      }),
              ),
              if (_type == InventoryIssueType.transfer)
                DropdownButtonFormField<String>(
                  initialValue: _destination,
                  decoration: const InputDecoration(
                    labelText: 'Destination store',
                  ),
                  items: stores
                      .where(
                        (store) =>
                            !store.isArchived && store.id != cart.storeId,
                      )
                      .map(
                        (store) => DropdownMenuItem(
                          value: store.id,
                          child: Text(store.name),
                        ),
                      )
                      .toList(),
                  onChanged: cart.isSubmitting
                      ? null
                      : (value) => setState(() => _destination = value),
                ),
              TextField(
                controller: _note,
                enabled: !cart.isSubmitting,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: cart.isEmpty || cart.isSubmitting ? null : _submit,
                child: cart.isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Submit ${_type.name} request (${cart.totalQuantity})',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
