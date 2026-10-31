// lib/features/inventory/batches/inventory_batches_screen.dart

import 'package:afyakit/features/inventory/records/deliveries/inventory_deliveries_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/inventory/items/inventory_item.dart';
import 'package:afyakit/features/inventory/items/inventory_items_providers.dart';
import 'package:afyakit/features/inventory/locations/inventory_location.dart';
import 'package:afyakit/features/inventory/locations/inventory_locations_providers.dart';
import 'package:afyakit/features/inventory/sources/inventory_source.dart';
import 'package:afyakit/features/inventory/sources/inventory_sources_providers.dart';
import 'package:afyakit/features/inventory/sources/inventory_sources_screen.dart';

import 'inventory_batch.dart';
import 'inventory_batches_providers.dart';

class InventoryBatchesScreen extends ConsumerStatefulWidget {
  const InventoryBatchesScreen({super.key});

  @override
  ConsumerState<InventoryBatchesScreen> createState() =>
      _InventoryBatchesScreenState();
}

class _InventoryBatchesScreenState
    extends ConsumerState<InventoryBatchesScreen> {
  String? storeId;
  bool showArchived = false;
  late Future<Map<String, String>> _itemNamesFuture;

  @override
  void initState() {
    super.initState();
    _itemNamesFuture = _loadItemNames();
  }

  /// Fetch item display names using the existing app-scoped catalogue API.
  /// Keep IDs for API requests, never for ordinary list presentation.
  Future<Map<String, String>> _loadItemNames() async {
    final types = await ref.read(itemTypesProvider.future);
    final service = await ref.read(inventoryItemsServiceProvider.future);
    final names = <String, String>{};
    for (final type in types) {
      // Include inactive item types: existing batches may still refer to them.
      for (var page = 1; ; page++) {
        final result = await service.list(
          typeId: type.typeId,
          page: page,
          perPage: 100,
        );
        for (final item in result.items) {
          names[item.id] = item.name;
        }
        if (!result.hasMore) break;
      }
    }
    return names;
  }

  String _displayDate(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _save(InventoryBatchInput input, {String? id}) async {
    final service = await ref.read(inventoryBatchesServiceProvider.future);

    if (id == null) {
      var createInput = input;

      // Positive stock must belong to a server-issued delivery session.
      // Reuse the open session instead of creating an unrelated delivery.
      if (input.quantity > 0) {
        final deliveries = await ref.read(
          inventoryDeliveriesServiceProvider.future,
        );
        final session =
            await deliveries.openSession() ?? await deliveries.ensureSession();

        createInput = InventoryBatchInput(
          itemId: input.itemId,
          storeId: input.storeId,
          quantity: input.quantity,
          batchNumber: input.batchNumber,
          source: input.source,
          receivedDate: input.receivedDate,
          expiryDate: input.expiryDate,
          deliveryId: session.deliveryId,
          notes: input.notes,
        );
      }

      await service.create(createInput);
      ref.invalidate(inventoryOpenDeliverySessionProvider);
    } else {
      final patch = Map<String, dynamic>.from(input.toJson())
        ..remove('item_id')
        ..remove('store_id')
        ..remove('quantity')
        ..remove('delivery_id');

      await service.update(id, patch);
    }

    ref.invalidate(inventoryBatchesProvider);
    ref.invalidate(archivedInventoryBatchesProvider);
    ref.invalidate(inventoryDeliveriesProvider);
  }

  Future<void> _openEditor({InventoryBatch? current}) async {
    try {
      // All active inventory locations can hold stock,
      // regardless of their descriptive location type.
      final locations = (await ref.read(
        inventoryLocationsProvider(null).future,
      )).where((location) => !location.isArchived).toList();

      final sources = await ref.read(inventorySourcesProvider.future);
      final itemTypes = await ref.read(itemTypesProvider.future);
      final itemsService = await ref.read(inventoryItemsServiceProvider.future);

      final items = <InventoryItem>[];

      for (final type in itemTypes) {
        if (!type.isActive) continue;

        for (var page = 1; ; page++) {
          final result = await itemsService.list(
            typeId: type.typeId,
            page: page,
            perPage: 100,
          );

          items.addAll(result.items.where((item) => !item.isArchived));

          if (!result.hasMore) break;
        }
      }

      if (!mounted) return;

      if (locations.isEmpty || items.isEmpty) {
        final message = locations.isEmpty
            ? 'Create an active inventory location first.'
            : 'Create an active inventory item first.';

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));

        return;
      }

      await showDialog<void>(
        context: context,
        builder: (_) => _BatchEditor(
          existing: current,
          items: items,
          locations: locations,
          sources: sources,
          onManageSources: _manageSources,
          onSave: (input) => _save(input, id: current?.id),
          onRemove: current == null ? null : () => _remove(current),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open batch editor: $error')),
      );
    }
  }

  Future<List<InventorySource>> _manageSources() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const InventorySourcesScreen()),
    );

    ref.invalidate(inventorySourcesProvider);
    ref.invalidate(allInventorySourcesProvider);

    return ref.read(inventorySourcesProvider.future);
  }

  Future<void> _remove(InventoryBatch batch) async {
    final service = await ref.read(inventoryBatchesServiceProvider.future);
    await service.remove(batch.id);
    ref.invalidate(inventoryBatchesProvider);
    ref.invalidate(archivedInventoryBatchesProvider);
    ref.invalidate(inventoryOpenDeliverySessionProvider);
    ref.invalidate(inventoryDeliveriesProvider);
  }

  Future<void> _restore(InventoryBatch batch) async {
    try {
      final service = await ref.read(inventoryBatchesServiceProvider.future);
      await service.restore(batch.id);
      ref.invalidate(inventoryBatchesProvider);
      ref.invalidate(archivedInventoryBatchesProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not restore batch: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(inventoryLocationsProvider(null));

    final batches = ref.watch(
      showArchived
          ? archivedInventoryBatchesProvider(storeId)
          : inventoryBatchesProvider(storeId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory batches'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(inventoryLocationsProvider(null));
              ref.invalidate(inventoryBatchesProvider);
              ref.invalidate(archivedInventoryBatchesProvider);
              setState(() => _itemNamesFuture = _loadItemNames());
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add batch'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: locations.when(
                    data: (values) => DropdownButtonFormField<String>(
                      initialValue: storeId,
                      decoration: const InputDecoration(labelText: 'Location'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All locations'),
                        ),
                        ...values
                            .where((v) => !v.isArchived)
                            .map(
                              (v) => DropdownMenuItem(
                                value: v.id,
                                child: Text(v.name),
                              ),
                            ),
                      ],
                      onChanged: (value) {
                        setState(() => storeId = value);
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text('Locations: $error'),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    const Text('Archived'),
                    Switch(
                      value: showArchived,
                      onChanged: (value) {
                        setState(() => showArchived = value);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: batches.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Could not load batches: $error')),
              data: (values) {
                final visible = showArchived
                    ? values.where((b) => b.isArchived).toList()
                    : values;

                if (visible.isEmpty) {
                  return const Center(child: Text('No batches found.'));
                }

                return FutureBuilder<Map<String, String>>(
                  future: _itemNamesFuture,
                  builder: (context, itemSnapshot) {
                    final itemNames =
                        itemSnapshot.data ?? const <String, String>{};
                    final locationNames = <String, String>{
                      for (final location
                          in locations.asData?.value ?? <InventoryLocation>[])
                        location.id: location.name,
                    };
                    return ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (_, index) {
                        final batch = visible[index];
                        final number = batch.batchNumber?.trim();
                        final title = number == null || number.isEmpty
                            ? 'Batch number not specified'
                            : number;
                        final itemName =
                            itemNames[batch.itemId] ??
                            (itemSnapshot.connectionState ==
                                    ConnectionState.waiting
                                ? 'Loading item…'
                                : 'Item unavailable');
                        final locationName =
                            locationNames[batch.storeId] ??
                            (locations.isLoading
                                ? 'Loading location…'
                                : 'Location unavailable');
                        final expiry = _displayDate(batch.expiryDate);
                        return ListTile(
                          title: Text(title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(itemName),
                              Text(
                                '$locationName • ${batch.itemType} '
                                '• ${batch.quantity} units'
                                '${expiry.isEmpty ? '' : ' • Expires $expiry'}',
                              ),
                            ],
                          ),
                          onTap: batch.isArchived
                              ? null
                              : () => _openEditor(current: batch),
                          trailing: batch.isArchived
                              ? IconButton(
                                  tooltip: 'Restore',
                                  icon: const Icon(Icons.restore),
                                  onPressed: () => _restore(batch),
                                )
                              : TextButton.icon(
                                  onPressed: () => _openEditor(current: batch),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit'),
                                ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BatchEditor extends StatefulWidget {
  const _BatchEditor({
    required this.items,
    required this.locations,
    required this.sources,
    required this.onManageSources,
    required this.onSave,
    this.onRemove,
    this.existing,
  });

  final List<InventoryItem> items;
  final List<InventoryLocation> locations;
  final List<InventorySource> sources;
  final Future<List<InventorySource>> Function() onManageSources;
  final InventoryBatch? existing;
  final Future<void> Function(InventoryBatchInput) onSave;
  final Future<void> Function()? onRemove;

  @override
  State<_BatchEditor> createState() => _BatchEditorState();
}

class _BatchEditorState extends State<_BatchEditor> {
  final formKey = GlobalKey<FormState>();

  late String itemId;
  late String storeId;

  late List<InventorySource> availableSources;

  String? selectedSourceId;
  String? legacySource;

  bool loadingSources = false;
  bool saving = false;
  bool removing = false;

  late final TextEditingController quantity;
  late final TextEditingController batchNumber;
  late final TextEditingController receivedDate;
  late final TextEditingController expiryDate;
  late final TextEditingController notes;

  @override
  void initState() {
    super.initState();

    final batch = widget.existing;

    itemId = batch?.itemId ?? widget.items.first.id;
    storeId = batch?.storeId ?? widget.locations.first.id;

    quantity = TextEditingController(text: batch?.quantity.toString() ?? '0');

    batchNumber = TextEditingController(text: batch?.batchNumber ?? '');

    availableSources = List.of(widget.sources);

    // Resolve an existing batch's source name against
    // the managed inventory source registry.
    final originalSource = (batch?.source ?? '').trim();

    if (originalSource.isNotEmpty) {
      for (final candidate in availableSources) {
        if (candidate.name.toLowerCase() == originalSource.toLowerCase()) {
          selectedSourceId = candidate.id;
          break;
        }
      }

      // Preserve historical free-text values that do not
      // match any currently registered source.
      if (selectedSourceId == null) {
        legacySource = originalSource;
      }
    }

    receivedDate = TextEditingController(text: batch?.receivedDate ?? '');

    expiryDate = TextEditingController(text: batch?.expiryDate ?? '');

    notes = TextEditingController(text: batch?.notes ?? '');
  }

  @override
  void dispose() {
    quantity.dispose();
    batchNumber.dispose();
    receivedDate.dispose();
    expiryDate.dispose();
    notes.dispose();

    super.dispose();
  }

  String? _dateValidator(String? value) {
    if (value == null || value.isEmpty) return null;

    final date = DateTime.tryParse(value);

    if (date == null || date.toIso8601String().substring(0, 10) != value) {
      return 'Use YYYY-MM-DD';
    }

    return null;
  }

  Future<void> _addOrManageSource() async {
    setState(() => loadingSources = true);

    try {
      final previousIds = availableSources.map((s) => s.id).toSet();

      // Open Sources management and reload the list on return.
      final updated = await widget.onManageSources();

      if (!mounted) return;

      final active = updated.where((source) => !source.isArchived).toList();

      final added = active
          .where((source) => !previousIds.contains(source.id))
          .toList();

      setState(() {
        availableSources = active;

        // Automatically select a newly created source,
        // provided exactly one was added.
        if (added.length == 1) {
          selectedSourceId = added.single.id;
          legacySource = null;
        } else if (selectedSourceId != null &&
            !active.any((source) => source.id == selectedSourceId)) {
          selectedSourceId = null;
        }
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not refresh sources: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => loadingSources = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    if (receivedDate.text.isNotEmpty &&
        expiryDate.text.isNotEmpty &&
        expiryDate.text.compareTo(receivedDate.text) < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expiry before received date')),
      );

      return;
    }

    // The current Batch API expects the source name.
    // Future delivery integration should use source_id.
    final chosenSource = availableSources.where(
      (source) => source.id == selectedSourceId,
    );

    final sourceName = chosenSource.isNotEmpty
        ? chosenSource.first.name
        : (legacySource ?? '');

    setState(() => saving = true);

    try {
      await widget.onSave(
        InventoryBatchInput(
          itemId: itemId,
          storeId: storeId,
          quantity: num.parse(quantity.text),
          batchNumber: batchNumber.text,
          source: sourceName,
          receivedDate: receivedDate.text.isEmpty ? null : receivedDate.text,
          expiryDate: expiryDate.text.isEmpty ? null : expiryDate.text,
          notes: notes.text,
        ),
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> _confirmRemove() async {
    if (widget.existing == null || widget.onRemove == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmationContext) => AlertDialog(
        title: const Text('Remove batch?'),
        content: const Text(
          'An open delivery batch will be cancelled. An empty batch will be '
          'archived. Received stock cannot be removed without a stock movement. '
          'Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmationContext, false),
            child: const Text('Keep batch'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(confirmationContext, true),
            child: const Text('Remove batch'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => removing = true);
    try {
      await widget.onRemove!();
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (error) {
      if (!mounted) return;
      final body = error.response?.data;
      final code = body is Map ? body['error']?.toString() : null;
      final message = code == 'nonempty-batch-requires-stock-movement'
          ? 'This batch contains received stock. Record a stock movement before removing it.'
          : code == 'draft-delivery-not-owned-by-actor'
          ? 'Only the owner of this delivery can remove its draft batches.'
          : 'Could not remove batch: ${code ?? error.message ?? 'Request failed'}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not remove batch: $error')));
    } finally {
      if (mounted) setState(() => removing = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'New batch' : 'Edit batch'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: itemId,
                decoration: const InputDecoration(labelText: 'Item'),
                items: widget.items
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: widget.existing == null
                    ? (value) {
                        if (value != null) {
                          setState(() => itemId = value);
                        }
                      }
                    : null,
              ),

              DropdownButtonFormField<String>(
                initialValue: storeId,
                decoration: const InputDecoration(labelText: 'Location'),
                items: widget.locations
                    .map(
                      (location) => DropdownMenuItem(
                        value: location.id,
                        child: Text(location.name),
                      ),
                    )
                    .toList(),
                onChanged: widget.existing == null
                    ? (value) {
                        if (value != null) {
                          setState(() => storeId = value);
                        }
                      }
                    : null,
              ),

              TextFormField(
                controller: quantity,
                readOnly: widget.existing != null,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  helperText: widget.existing == null
                      ? null
                      : 'Use a stock movement to change quantity',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final number = num.tryParse(value ?? '');

                  if (number == null || !number.isFinite || number < 0) {
                    return 'Enter a non-negative quantity';
                  }

                  return null;
                },
              ),

              TextFormField(
                controller: batchNumber,
                decoration: const InputDecoration(labelText: 'Batch number'),
              ),

              // Managed Inventory Sources selector.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('source:$selectedSourceId:$legacySource'),
                      initialValue:
                          selectedSourceId ??
                          (legacySource != null ? '__legacy__' : null),
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Source'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Not specified'),
                        ),

                        if (legacySource != null)
                          DropdownMenuItem<String>(
                            value: '__legacy__',
                            child: Text(
                              '$legacySource (previous entry)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                        ...availableSources.map(
                          (source) => DropdownMenuItem<String>(
                            value: source.id,
                            child: Text(
                              source.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: saving || loadingSources
                          ? null
                          : (value) {
                              setState(() {
                                selectedSourceId = value == '__legacy__'
                                    ? null
                                    : value;

                                if (value != '__legacy__') {
                                  legacySource = null;
                                }
                              });
                            },
                    ),
                  ),

                  const SizedBox(width: 8),

                  IconButton(
                    tooltip: 'Add or manage sources',
                    icon: loadingSources
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_circle_outline),
                    onPressed: saving || loadingSources
                        ? null
                        : _addOrManageSource,
                  ),
                ],
              ),

              TextFormField(
                controller: receivedDate,
                decoration: const InputDecoration(
                  labelText: 'Received (YYYY-MM-DD)',
                ),
                validator: _dateValidator,
              ),

              TextFormField(
                controller: expiryDate,
                decoration: const InputDecoration(
                  labelText: 'Expiry (YYYY-MM-DD)',
                ),
                validator: _dateValidator,
              ),

              TextFormField(
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      if (widget.existing != null && widget.onRemove != null)
        TextButton.icon(
          onPressed: saving || removing ? null : _confirmRemove,
          icon: const Icon(Icons.delete_outline),
          label: Text(removing ? 'Removing…' : 'Delete'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
        ),
      TextButton(
        onPressed: saving || removing
            ? null
            : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving || removing ? null : _submit,
        child: Text(saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
}
