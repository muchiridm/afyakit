import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'inventory_item.dart';
import 'inventory_items_providers.dart';

/// Shared management UI. The Items API remains the only owner of type definitions.
Future<void> showItemTypeManager(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _ItemTypeManager(),
);

class _ItemTypeManager extends ConsumerStatefulWidget {
  const _ItemTypeManager();

  @override
  ConsumerState<_ItemTypeManager> createState() => _ItemTypeManagerState();
}

class _ItemTypeManagerState extends ConsumerState<_ItemTypeManager> {
  bool busy = false;

  Future<void> _create() async {
    final data = await showDialog<_TypeDraft>(
      context: context,
      builder: (_) => const _TypeEditor(),
    );
    if (data == null || !mounted) return;
    await _run(() async {
      final service = await ref.read(inventoryItemsServiceProvider.future);
      await service.createType(
        typeId: data.id,
        label: data.label,
        attributes: data.attributes,
      );
    });
  }

  Future<void> _rename(InventoryItemType type) async {
    final controller = TextEditingController(text: type.label);
    try {
      final label = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Rename ${type.label}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Display label'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (label == null || !mounted) return;
      await _run(() async {
        final service = await ref.read(inventoryItemsServiceProvider.future);
        await service.renameType(type.typeId, label);
      });
    } finally {
      controller.dispose();
    }
  }

  Future<void> _archive(InventoryItemType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Deactivate ${type.label}?'),
        content: const Text(
          'Only types with no inventory items can be deactivated. Existing definitions are retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final service = await ref.read(inventoryItemsServiceProvider.future);
      await service.archiveType(type.typeId);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      ref.invalidate(itemTypesProvider);
      ref.invalidate(allItemTypesProvider);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item type operation failed: $error')),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(allItemTypesProvider);
    return AlertDialog(
      title: const Text('Manage item types'),
      content: SizedBox(
        width: 540,
        height: 410,
        child: types.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Unable to load types: $error')),
          data: (items) => ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, index) {
              final type = items[index];
              return ListTile(
                title: Text(type.label),
                subtitle: Text(
                  '${type.typeId} • ${type.attributes.length} attributes${type.isActive ? '' : ' • Inactive'}',
                ),
                trailing: type.isActive
                    ? Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Rename',
                            onPressed: busy ? null : () => _rename(type),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Deactivate',
                            onPressed: busy ? null : () => _archive(type),
                            icon: const Icon(Icons.archive_outlined),
                          ),
                        ],
                      )
                    : null,
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: busy ? null : _create,
          icon: const Icon(Icons.add),
          label: const Text('New type'),
        ),
      ],
    );
  }
}

class _TypeDraft {
  final String id;
  final String label;
  final List<InventoryAttribute> attributes;
  const _TypeDraft(this.id, this.label, this.attributes);
}

class _AttributeDraft {
  final key = TextEditingController();
  final label = TextEditingController();
  String dataType = 'string';
  bool required = false;
  void dispose() {
    key.dispose();
    label.dispose();
  }
}

class _TypeEditor extends StatefulWidget {
  const _TypeEditor();
  @override
  State<_TypeEditor> createState() => _TypeEditorState();
}

class _TypeEditorState extends State<_TypeEditor> {
  final id = TextEditingController();
  final label = TextEditingController();
  final attributes = <_AttributeDraft>[];
  String? error;

  @override
  void dispose() {
    id.dispose();
    label.dispose();
    for (final attribute in attributes) {
      attribute.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final typeId = id.text.trim();
    final typeLabel = label.text.trim();
    final typePattern = RegExp(r'^[a-z][a-z0-9_]{1,63}$');
    final keyPattern = RegExp(r'^[a-z][a-zA-Z0-9_]{0,63}$');
    final keys = <String>{};
    if (!typePattern.hasMatch(typeId) ||
        typeLabel.isEmpty ||
        typeLabel.length > 100) {
      setState(() => error = 'Enter a valid type ID and label.');
      return;
    }
    final definitions = <InventoryAttribute>[];
    for (final draft in attributes) {
      final key = draft.key.text.trim();
      final fieldLabel = draft.label.text.trim();
      if (!keyPattern.hasMatch(key) ||
          !keys.add(key) ||
          fieldLabel.isEmpty ||
          fieldLabel.length > 100) {
        setState(
          () => error =
              'Attribute keys must be unique and labels cannot be empty.',
        );
        return;
      }
      definitions.add(
        InventoryAttribute(
          key: key,
          label: fieldLabel,
          dataType: draft.dataType,
          required: draft.required,
        ),
      );
    }
    Navigator.pop(context, _TypeDraft(typeId, typeLabel, definitions));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New item type'),
    content: SizedBox(
      width: 570,
      height: 470,
      child: ListView(
        children: [
          TextField(
            controller: id,
            decoration: const InputDecoration(
              labelText: 'Type ID',
              hintText: 'medical_supply',
            ),
          ),
          TextField(
            controller: label,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Display label'),
          ),
          const SizedBox(height: 12),
          const Text('Attributes (optional)'),
          for (int i = 0; i < attributes.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: attributes[i].key,
                            decoration: const InputDecoration(
                              labelText: 'Key',
                              hintText: 'manufacturer',
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove attribute',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            final removed = attributes.removeAt(i);
                            setState(() {});
                            // Controllers belong to the draft, which is no longer rendered.
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => removed.dispose(),
                            );
                          },
                        ),
                      ],
                    ),
                    TextField(
                      controller: attributes[i].label,
                      decoration: const InputDecoration(labelText: 'Label'),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: attributes[i].dataType,
                            decoration: const InputDecoration(
                              labelText: 'Data type',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'string',
                                child: Text('Text'),
                              ),
                              DropdownMenuItem(
                                value: 'number',
                                child: Text('Number'),
                              ),
                              DropdownMenuItem(
                                value: 'boolean',
                                child: Text('Yes / No'),
                              ),
                              DropdownMenuItem(
                                value: 'string_array',
                                child: Text('List of text values'),
                              ),
                            ],
                            onChanged: (v) => setState(
                              () => attributes[i].dataType = v ?? 'string',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('Required'),
                        Checkbox(
                          value: attributes[i].required,
                          onChanged: (v) => setState(
                            () => attributes[i].required = v ?? false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          TextButton.icon(
            onPressed: attributes.length >= 40
                ? null
                : () => setState(() => attributes.add(_AttributeDraft())),
            icon: const Icon(Icons.add),
            label: const Text('Add attribute'),
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const Text(
            'You can append optional attributes later in Item Preferences; existing keys and types are protected.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Create type')),
    ],
  );
}
