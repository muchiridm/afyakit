import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/inventory/items/inventory_item.dart';
import 'inventory_reorders_providers.dart';

class InventoryReordersScreen extends ConsumerStatefulWidget {
  const InventoryReordersScreen({super.key});

  @override
  ConsumerState<InventoryReordersScreen> createState() => _InventoryReordersScreenState();
}

class _InventoryReordersScreenState extends ConsumerState<InventoryReordersScreen> {
  String _query = '';
  String? _selectedType;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _copyProposal() async {
    final draft = ref.read(inventoryReorderDraftProvider);
    if (draft.lines.isEmpty) return;
    final service = await ref.read(inventoryReordersServiceProvider.future);
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: service.toCsv(draft)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Proposal CSV copied. Paste into a .csv file to save it.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryReorderItemsProvider);
    final draft = ref.watch(inventoryReorderDraftProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reorder Proposal')),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load items: $error', textAlign: TextAlign.center),
            TextButton(
              onPressed: () => ref.invalidate(inventoryReorderItemsProvider),
              child: const Text('Retry'),
            ),
          ],
        )),
        data: (items) {
          final types = items.map((item) => item.itemType).toSet().toList()..sort();
          final selectedType = types.contains(_selectedType) ? _selectedType : null;
          final filtered = items.where((item) {
            if (selectedType != null && item.itemType != selectedType) return false;
            final q = _query.trim().toLowerCase();
            return q.isEmpty || item.name.toLowerCase().contains(q) ||
                item.id.toLowerCase().contains(q);
          }).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search items'),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey(selectedType ?? 'all'),
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Item type'),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('All types')),
                    for (final type in types) DropdownMenuItem(value: type, child: Text(type)),
                  ],
                  onChanged: (value) => setState(() => _selectedType = value),
                ),
              ]),
            ),
            Expanded(child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) => _itemTile(filtered[index], draft.lines[filtered[index].id]?.quantity ?? 0),
            )),
            SafeArea(top: false, child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: 'Proposal note (optional)'),
                  onChanged: ref.read(inventoryReorderDraftProvider.notifier).setNote,
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text('${draft.itemCount} items • ${draft.totalUnits} units')),
                  TextButton(onPressed: draft.itemCount == 0 ? null : () {
                    ref.read(inventoryReorderDraftProvider.notifier).clear();
                    _noteController.clear();
                  }, child: const Text('Clear')),
                  FilledButton.icon(
                    onPressed: draft.itemCount == 0 ? null : _copyProposal,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy CSV'),
                  ),
                ]),
                const Text('Draft only — no purchase order is saved and no stock changes.',
                    style: TextStyle(fontSize: 12)),
              ]),
            )),
          ]);
        },
      ),
    );
  }

  Widget _itemTile(InventoryItem item, int quantity) {
    final notifier = ref.read(inventoryReorderDraftProvider.notifier);
    return ListTile(
      title: Text(item.name.isNotEmpty ? item.name : item.id),
      subtitle: Text('${item.itemType} • ${item.id}'),
      trailing: SizedBox(width: 132, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        IconButton(
          tooltip: 'Decrease',
          onPressed: quantity == 0 ? null : () => notifier.setQuantity(item, quantity - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$quantity'),
        IconButton(
          tooltip: 'Increase',
          onPressed: () => notifier.setQuantity(item, quantity + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ])),
    );
  }
}
