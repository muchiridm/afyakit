import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'inventory_source.dart';
import 'inventory_sources_providers.dart';

class InventorySourcesScreen extends ConsumerStatefulWidget {
  const InventorySourcesScreen({super.key});

  @override
  ConsumerState<InventorySourcesScreen> createState() => _InventorySourcesScreenState();
}

class _InventorySourcesScreenState extends ConsumerState<InventorySourcesScreen> {
  bool showArchived = false;
  bool busy = false;

  void _refresh() {
    ref.invalidate(inventorySourcesProvider);
    ref.invalidate(allInventorySourcesProvider);
  }

  Future<void> _edit({InventorySource? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final type = TextEditingController(text: existing?.sourceType ?? '');
    final description = TextEditingController(text: existing?.description ?? '');
    final formKey = GlobalKey<FormState>();
    try {
      final input = await showDialog<InventorySourceInput>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(existing == null ? 'Add source' : 'Edit source'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      autofocus: true,
                      maxLength: 160,
                      decoration: const InputDecoration(labelText: 'Source name *'),
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Enter at least 2 characters' : null,
                    ),
                    TextFormField(
                      controller: type,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Source type (optional)',
                        hintText: 'Wholesaler, Manufacturer, Donation',
                      ),
                    ),
                    TextFormField(
                      controller: description,
                      maxLength: 500,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description (optional)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(dialogContext, InventorySourceInput(
                  name: name.text, sourceType: type.text, description: description.text,
                ));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (input == null || !mounted) return;
      setState(() => busy = true);
      try {
        final service = await ref.read(inventorySourcesServiceProvider.future);
        if (existing == null) {
          await service.create(input);
        } else {
          await service.update(existing.id, input);
        }
        _refresh();
      } catch (error) {
        _error(error);
      } finally {
        if (mounted) setState(() => busy = false);
      }
    } finally {
      name.dispose();
      type.dispose();
      description.dispose();
    }
  }

  Future<void> _toggleArchived(InventorySource source) async {
    if (busy) return;
    if (!source.isArchived) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Archive source?'),
          content: Text('Archive ${source.name}? Historical stock records will be preserved.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Archive')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => busy = true);
    try {
      final service = await ref.read(inventorySourcesServiceProvider.future);
      if (source.isArchived) {
        await service.restore(source.id);
      } else {
        await service.archive(source.id);
      }
      _refresh();
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Inventory sources: $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(allInventorySourcesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory sources'),
        actions: [
          IconButton(onPressed: busy ? null : _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : () => _edit(),
        icon: const Icon(Icons.add), label: const Text('Add source'),
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Show archived sources'),
            value: showArchived,
            onChanged: (value) => setState(() => showArchived = value),
          ),
          if (busy) const LinearProgressIndicator(),
          Expanded(child: sourcesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Could not load sources: $error')),
            data: (sources) {
              final visible = sources.where((s) => showArchived || !s.isArchived).toList()
                ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              if (visible.isEmpty) return const Center(child: Text('No inventory sources found.'));
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final source = visible[index];
                  return ListTile(
                    title: Text(source.name),
                    subtitle: Text([
                      if (source.sourceType?.isNotEmpty == true) source.sourceType!,
                      if (source.description?.isNotEmpty == true) source.description!,
                      if (source.isArchived) 'Archived',
                    ].join(' • ')),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (!source.isArchived)
                        IconButton(
                          tooltip: 'Edit', icon: const Icon(Icons.edit_outlined),
                          onPressed: busy ? null : () => _edit(existing: source),
                        ),
                      IconButton(
                        tooltip: source.isArchived ? 'Restore' : 'Archive',
                        icon: Icon(source.isArchived ? Icons.restore : Icons.archive_outlined),
                        onPressed: busy ? null : () => _toggleArchived(source),
                      ),
                    ]),
                  );
                },
              );
            },
          )),
        ],
      ),
    );
  }
}
