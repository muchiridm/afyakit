import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'inventory_item.dart';
import 'inventory_items_providers.dart';
import 'item_type_management.dart';
import 'package:afyakit/features/inventory/preferences/item_preferences_providers.dart';
import 'package:afyakit/features/inventory/preferences/item_preference.dart';

// Dynamic catalogue + editor, driven by item-type definitions from the backend.
class InventoryItemsScreen extends ConsumerStatefulWidget {
  const InventoryItemsScreen({super.key});
  @override
  ConsumerState<InventoryItemsScreen> createState() =>
      _InventoryItemsScreenState();
}

class _InventoryItemsScreenState extends ConsumerState<InventoryItemsScreen> {
  String? selectedType;
  int page = 1;
  @override
  Widget build(BuildContext context) {
    final types = ref.watch(itemTypesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Items'),
        actions: [
          IconButton(
            tooltip: 'Create item type',
            onPressed: () => showItemTypeManager(context),
            icon: const Icon(Icons.category_outlined),
          ),
        ],
      ),
      body: types.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load item types: $e')),
        data: (all) {
          if (all.isEmpty) {
            return const Center(
              child: Text('No item types configured. Create a type first.'),
            );
          }
          final type = all.any((t) => t.typeId == selectedType)
              ? all.firstWhere((t) => t.typeId == selectedType)
              : all.first;
          final items = ref.watch(itemsProvider(type.typeId));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<String>(
                  key: ValueKey(type.typeId),
                  initialValue: type.typeId,
                  decoration: const InputDecoration(
                    labelText: 'Item type',
                    border: OutlineInputBorder(),
                  ),
                  items: all
                      .map(
                        (t) => DropdownMenuItem(
                          value: t.typeId,
                          child: Text(t.label),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    selectedType = v;
                    page = 1;
                  }),
                ),
              ),
              Expanded(
                child: items.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Could not load items: $e')),
                  data: (page) => RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(itemsProvider(type.typeId));
                      await ref.read(itemsProvider(type.typeId).future);
                    },
                    child: ListView(
                      children: [
                        for (final item in page.items)
                          ListTile(
                            title: Text(item.name),
                            subtitle: Text(
                              [
                                type.label,
                              ].join(' • '),
                            ),
                            onTap: () => _edit(type, existing: item),
                          ),
                        if (page.hasMore)
                          ListTile(
                            title: const Text('More items available'),
                            subtitle: const Text(
                              'Open the next page in the catalogue when pagination is enabled.',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: types.valueOrNull?.isNotEmpty == true
          ? FloatingActionButton.extended(
              onPressed: () {
                final all = types.valueOrNull!;
                final type = all.any((t) => t.typeId == selectedType)
                    ? all.firstWhere((t) => t.typeId == selectedType)
                    : all.first;
                _edit(type);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            )
          : null,
    );
  }

  Future<void> _edit(InventoryItemType type, {InventoryItem? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final values = <String, TextEditingController>{
      for (final field in type.attributes)
        if (field.dataType != 'boolean')
          field.key: TextEditingController(
            text: existing?.attributes[field.key] is List
                ? (existing!.attributes[field.key] as List).join(', ')
                : '${existing?.attributes[field.key] ?? ''}',
          ),
    };
    final flags = <String, bool>{
      for (final field in type.attributes)
        if (field.dataType == 'boolean')
          field.key: existing?.attributes[field.key] == true,
    };
    final selectedMultiple = <String, Set<String>>{
      for (final field in type.attributes)
        if (field.dataType == 'string_array')
          field.key: (existing?.attributes[field.key] is List
                  ? (existing!.attributes[field.key] as List).map((v) => '$v')
                  : const <String>[])
              .toSet(),
    };
    try {
      // Reuse the one Preferences provider. No duplicate API code in Items.
      final optionFutures = <String, Future<List<String>>>{
        for (final field in type.attributes)
          if (field.dataType == 'string' || field.dataType == 'string_array')
            field.key: ref.read(
              itemPreferenceValuesProvider(ItemPreferenceKey(type.typeId, field.key)).future,
            ),
      };
      final options = <String, List<String>>{};
      for (final entry in optionFutures.entries) {
        options[entry.key] = await entry.value;
      }
      if (!mounted) return;

      final saved = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, refresh) => AlertDialog(
            title: Text(existing == null ? 'New ${type.label}' : 'Edit ${type.label}'),
            content: SizedBox(
              width: 510,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(controller: name, decoration: const InputDecoration(labelText: 'Name *')),
                    for (final field in type.attributes) ...[
                      const SizedBox(height: 12),
                      if (field.dataType == 'boolean')
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(field.label),
                          value: flags[field.key] ?? false,
                          onChanged: (v) => refresh(() => flags[field.key] = v ?? false),
                        )
                      else if (field.dataType == 'string_array' &&
                          (options[field.key]?.isNotEmpty ?? false)) ...[
                        Text('${field.label}${field.required ? ' *' : ''}'),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final option in {
                              ...options[field.key]!,
                              ...selectedMultiple[field.key]!,
                            })
                              FilterChip(
                                label: Text(option),
                                selected: selectedMultiple[field.key]!.contains(option),
                                onSelected: (selected) => refresh(() {
                                  if (selected) {
                                    selectedMultiple[field.key]!.add(option);
                                  } else {
                                    selectedMultiple[field.key]!.remove(option);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ] else if (field.dataType == 'string' &&
                          (options[field.key]?.isNotEmpty ?? false))
                        DropdownButtonFormField<String>(
                          key: ValueKey('${type.typeId}:${field.key}'),
                          value: {
                            ...options[field.key]!,
                            if (values[field.key]!.text.trim().isNotEmpty)
                              values[field.key]!.text.trim(),
                          }.contains(values[field.key]!.text.trim()) &&
                                  values[field.key]!.text.trim().isNotEmpty
                              ? values[field.key]!.text.trim()
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: '${field.label}${field.required ? ' *' : ''}',
                          ),
                          items: [
                            for (final option in {
                              ...options[field.key]!,
                              if (values[field.key]!.text.trim().isNotEmpty)
                                values[field.key]!.text.trim(),
                            })
                              DropdownMenuItem(value: option, child: Text(option)),
                          ],
                          onChanged: (value) => refresh(
                            () => values[field.key]!.text = value ?? '',
                          ),
                        )
                      else
                        TextField(
                          controller: values[field.key],
                          keyboardType: field.dataType == 'number'
                              ? const TextInputType.numberWithOptions(decimal: true)
                              : TextInputType.text,
                          decoration: InputDecoration(
                            labelText: '${field.label}${field.required ? ' *' : ''}',
                            helperText: field.dataType == 'string_array'
                                ? 'Separate values with commas (configure options in Preferences)'
                                : null,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (name.text.trim().isEmpty) return;
                  final attrs = <String, dynamic>{...flags};
                  for (final field in type.attributes) {
                    if (field.dataType == 'boolean') continue;
                    final raw = values[field.key]!.text.trim();
                    if (field.dataType == 'string_array') {
                      final chosen = (options[field.key]?.isNotEmpty ?? false)
                          ? selectedMultiple[field.key]!.toList()
                          : raw.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList();
                      if (field.required && chosen.isEmpty) return;
                      if (chosen.isNotEmpty) attrs[field.key] = chosen;
                    } else {
                      if (field.required && raw.isEmpty) return;
                      if (raw.isEmpty) continue;
                      if (field.dataType == 'number') {
                        final parsed = num.tryParse(raw);
                        if (parsed == null) return;
                        attrs[field.key] = parsed;
                      } else {
                        attrs[field.key] = raw;
                      }
                    }
                  }
                  Navigator.pop(ctx, {
                    'name': name.text.trim(),
                    'attributes': attrs,
                  });
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (saved == null) return;
      final svc = await ref.read(inventoryItemsServiceProvider.future);
      if (existing == null) {
        await svc.create(InventoryItemInput(
          itemType: type.typeId,
          name: saved['name'] as String,
          attributes: Map<String, dynamic>.from(saved['attributes'] as Map),
        ));
      } else {
        await svc.update(existing.id, saved);
      }
      ref.invalidate(itemsProvider(type.typeId));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $error')),
      );
    } finally {
      name.dispose();
      for (final c in values.values) { c.dispose(); }
    }
  }
}
