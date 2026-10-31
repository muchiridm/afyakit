import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/inventory/items/inventory_items_providers.dart';
import 'package:afyakit/features/inventory/items/inventory_item.dart';
import 'package:afyakit/features/inventory/items/item_type_management.dart';
import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'item_preference.dart';
import 'item_preferences_providers.dart';

class ItemPreferencesScreen extends ConsumerStatefulWidget {
  const ItemPreferencesScreen({super.key});

  @override
  ConsumerState<ItemPreferencesScreen> createState() =>
      _ItemPreferencesScreenState();
}

class _ItemPreferencesScreenState extends ConsumerState<ItemPreferencesScreen> {
  String? selectedType;

  Future<void> _addAttribute(InventoryItemType type) async {
    final keyController = TextEditingController();
    final labelController = TextEditingController();
    String dataType = 'string';
    try {
      final attribute = await showDialog<InventoryAttribute>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, refresh) => AlertDialog(
            title: Text('Add attribute to ${type.label}'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: keyController,
                    decoration: const InputDecoration(
                      labelText: 'Field key',
                      hintText: 'formulation',
                    ),
                  ),
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(
                      labelText: 'Display label',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: dataType,
                    decoration: const InputDecoration(labelText: 'Value type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'string',
                        child: Text('Single text / selection'),
                      ),
                      DropdownMenuItem(
                        value: 'string_array',
                        child: Text('Multiple text selections'),
                      ),
                      DropdownMenuItem(value: 'number', child: Text('Number')),
                      DropdownMenuItem(
                        value: 'boolean',
                        child: Text('Yes / No'),
                      ),
                    ],
                    onChanged: (value) =>
                        refresh(() => dataType = value ?? 'string'),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'New attributes are optional to protect existing items.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final key = keyController.text.trim();
                  final label = labelController.text.trim();
                  if (!RegExp(r'^[a-z][a-zA-Z0-9_]{0,63}$').hasMatch(key) ||
                      label.isEmpty ||
                      label.length > 100 ||
                      type.attributes.any((a) => a.key == key)) {
                    return;
                  }
                  Navigator.pop(
                    dialogContext,
                    InventoryAttribute(
                      key: key,
                      label: label,
                      dataType: dataType,
                      required: false,
                    ),
                  );
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      );
      if (attribute == null || !mounted) return;
      final service = await ref.read(inventoryItemsServiceProvider.future);
      await service.addTypeAttribute(type, attribute);
      ref.invalidate(itemTypesProvider);
      ref.invalidate(allItemTypesProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add attribute: $error')),
        );
      }
    } finally {
      keyController.dispose();
      labelController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(itemTypesProvider);
    return AppPage(
      scrollable: false,
      maxWidth: 900,
      header: const AppHeader(title: 'Item Preferences'),
      body: types.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to load item types: $error')),
        data: (allTypes) {
          final active = allTypes.where((type) => type.isActive).toList();
          if (active.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No active item types configured.'),
                  FilledButton.icon(
                    onPressed: () => showItemTypeManager(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Manage item types'),
                  ),
                ],
              ),
            );
          }
          final type = active.firstWhere(
            (type) => type.typeId == selectedType,
            orElse: () => active.first,
          );
          final fields = <String, String>{};
          for (final attribute in type.attributes) {
            if ((attribute.dataType == 'string' ||
                attribute.dataType == 'string_array')) {
              fields[attribute.key] = attribute.label.isEmpty
                  ? attribute.key
                  : attribute.label;
            }
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => showItemTypeManager(context),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Manage item types'),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _addAttribute(type),
                    icon: const Icon(Icons.add),
                    label: const Text('Add attribute'),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  key: ValueKey(type.typeId),
                  initialValue: type.typeId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Item type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final itemType in active)
                      DropdownMenuItem(
                        value: itemType.typeId,
                        child: Text(itemType.label),
                      ),
                  ],
                  onChanged: (value) => setState(() => selectedType = value),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final field in fields.entries)
                      _PreferenceFieldCard(
                        key: ValueKey('${type.typeId}:${field.key}'),
                        preferenceKey: ItemPreferenceKey(
                          type.typeId,
                          field.key,
                        ),
                        label: field.value,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PreferenceFieldCard extends ConsumerStatefulWidget {
  const _PreferenceFieldCard({
    super.key,
    required this.preferenceKey,
    required this.label,
  });
  final ItemPreferenceKey preferenceKey;
  final String label;

  @override
  ConsumerState<_PreferenceFieldCard> createState() =>
      _PreferenceFieldCardState();
}

class _PreferenceFieldCardState extends ConsumerState<_PreferenceFieldCard> {
  final input = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> _mutate({String? remove}) async {
    final value = (remove ?? input.text).trim();
    if (value.isEmpty || saving) return;
    setState(() => saving = true);
    try {
      final service = await ref.read(itemPreferencesServiceProvider.future);
      if (remove == null) {
        await service.add(
          widget.preferenceKey.itemType,
          widget.preferenceKey.field,
          value,
        );
      } else {
        await service.remove(
          widget.preferenceKey.itemType,
          widget.preferenceKey.field,
          value,
        );
      }
      if (!mounted) return;
      if (remove == null) input.clear();
      ref.invalidate(itemPreferenceValuesProvider(widget.preferenceKey));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final values = ref.watch(
      itemPreferenceValuesProvider(widget.preferenceKey),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            values.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Unable to load: $error'),
              data: (items) => Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final value in items)
                    InputChip(
                      label: Text(value),
                      onDeleted: saving ? null : () => _mutate(remove: value),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    decoration: InputDecoration(
                      hintText: 'Add ${widget.label.toLowerCase()}',
                      isDense: true,
                    ),
                    onSubmitted: saving ? null : (_) => _mutate(),
                  ),
                ),
                IconButton(
                  tooltip: 'Add value',
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  onPressed: saving ? null : () => _mutate(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
