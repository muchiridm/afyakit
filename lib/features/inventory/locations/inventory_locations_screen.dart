import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'inventory_location.dart';
import 'inventory_locations_providers.dart';

class InventoryLocationsScreen extends ConsumerStatefulWidget {
  const InventoryLocationsScreen({super.key});
  @override
  ConsumerState<InventoryLocationsScreen> createState() =>
      _InventoryLocationsScreenState();
}

class _InventoryLocationsScreenState
    extends ConsumerState<InventoryLocationsScreen> {
  final _name = TextEditingController();
  String? _typeId;
  bool _includeArchived = false, _saving = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(inventoryLocationsProvider);
    ref.invalidate(archivedInventoryLocationsProvider);
    ref.invalidate(inventoryLocationTypesProvider);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      if (mounted) _refresh();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _ask(
    String title,
    String label, {
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _addLocation() async {
    final name = _name.text.trim();
    final type = _typeId;
    if (name.length < 2 || type == null) return;
    await _run(() async {
      final svc = await ref.read(inventoryLocationsServiceProvider.future);
      await svc.create(name: name, typeId: type);
      _name.clear();
      if (mounted) setState(() {});
    });
  }

  Future<void> _createType() async {
    final id = await _ask('New location type', 'Type ID, e.g. warehouse');
    if (id == null) return;
    if (!RegExp(r'^[a-z][a-z0-9_-]{0,63}$').hasMatch(id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Use a lowercase type ID (letters, numbers, _ or -).',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    final label = await _ask('New location type', 'Display name', initial: id);
    if (label == null || label.length < 2) return;
    await _run(() async {
      final svc = await ref.read(inventoryLocationsServiceProvider.future);
      await svc.createType(id: id, label: label);
    });
    if (mounted) setState(() => _typeId = id);
  }

  Future<void> _editType(InventoryLocationType type) async {
    final label = await _ask(
      'Rename location type',
      'Display name',
      initial: type.label,
    );
    if (label == null || label.length < 2 || label == type.label) return;
    await _run(() async {
      (await ref.read(
        inventoryLocationsServiceProvider.future,
      )).renameType(type.id, label);
    });
  }

  Future<void> _toggleType(InventoryLocationType type) async {
    if (type.isActive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Deactivate location type?'),
          content: Text(
            'Deactivate ${type.label}? Types assigned to any location cannot be deactivated.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _run(() async {
      final svc = await ref.read(inventoryLocationsServiceProvider.future);
      if (type.isActive) {
        await svc.deactivateType(type.id);
      } else {
        await svc.reactivateType(type.id);
      }
    });
    if (mounted && type.isActive && _typeId == type.id) {
      setState(() => _typeId = null);
    }
  }

  Future<void> _manageTypes(List<InventoryLocationType> types) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manage location types'),
        content: SizedBox(
          width: 480,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final type in types)
                ListTile(
                  title: Text(type.label),
                  subtitle: Text(type.id),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Rename',
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _editType(type);
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: type.isActive ? 'Deactivate' : 'Reactivate',
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _toggleType(type);
                        },
                        icon: Icon(
                          type.isActive
                              ? Icons.archive_outlined
                              : Icons.restore,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _createType();
            },
            icon: const Icon(Icons.add),
            label: const Text('New type'),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(InventoryLocation loc) async {
    final name = await _ask('Rename location', 'Name', initial: loc.name);
    if (name == null || name.length < 2 || name == loc.name) return;
    await _run(() async {
      (await ref.read(
        inventoryLocationsServiceProvider.future,
      )).update(loc.id, name: name);
    });
  }

  Future<void> _toggleLocation(InventoryLocation loc) async {
    if (!loc.isArchived) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Archive location?'),
          content: Text(
            'Archive ${loc.name}? Active batches prevent archiving.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _run(() async {
      final svc = await ref.read(inventoryLocationsServiceProvider.future);
      if (loc.isArchived) {
        await svc.restore(loc.id);
      } else {
        await svc.archive(loc.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(inventoryLocationTypesProvider);
    final locationsAsync = ref.watch(
      _includeArchived
          ? archivedInventoryLocationsProvider(null)
          : inventoryLocationsProvider(null),
    );
    final types = typesAsync.valueOrNull ?? <InventoryLocationType>[];
    final active = types.where((t) => t.isActive).toList();
    final selected = active.any((t) => t.id == _typeId) ? _typeId : null;
    return AppPage(
      maxWidth: 700,
      scrollable: false,
      header: const AppHeader(title: 'Inventory Locations'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Location name'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selected,
                    decoration: const InputDecoration(
                      labelText: 'Location type',
                    ),
                    items: [
                      for (final t in active)
                        DropdownMenuItem(value: t.id, child: Text(t.label)),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _typeId = v),
                  ),
                ),
                IconButton(
                  tooltip: 'Manage types',
                  onPressed: _saving || typesAsync.isLoading
                      ? null
                      : () => _manageTypes(types),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed:
                  _saving || selected == null || _name.text.trim().length < 2
                  ? null
                  : _addLocation,
              icon: const Icon(Icons.add),
              label: const Text('Add location'),
            ),
            SwitchListTile(
              title: const Text('Show archived locations'),
              value: _includeArchived,
              onChanged: (v) => setState(() => _includeArchived = v),
            ),
            const Divider(),
            Expanded(
              child: locationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Unable to load locations: $e')),
                data: (locations) => locations.isEmpty
                    ? const Center(child: Text('No locations yet'))
                    : ListView.builder(
                        itemCount: locations.length,
                        itemBuilder: (ctx, i) {
                          final loc = locations[i];
                          final matches = types.where(
                            (t) => t.id == loc.typeId,
                          );
                          final label = matches.isEmpty
                              ? loc.typeId
                              : matches.first.label;
                          return ListTile(
                            title: Text(loc.name),
                            subtitle: Text(label),
                            enabled: !_saving,
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                if (!loc.isArchived)
                                  IconButton(
                                    tooltip: 'Rename',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: _saving
                                        ? null
                                        : () => _rename(loc),
                                  ),
                                IconButton(
                                  tooltip: loc.isArchived
                                      ? 'Restore'
                                      : 'Archive',
                                  icon: Icon(
                                    loc.isArchived
                                        ? Icons.restore
                                        : Icons.archive_outlined,
                                  ),
                                  onPressed: _saving
                                      ? null
                                      : () => _toggleLocation(loc),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
