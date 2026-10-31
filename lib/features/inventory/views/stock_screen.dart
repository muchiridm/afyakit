import 'package:afyakit/features/inventory/items/inventory_items_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/inventory/items/inventory_items_providers.dart';
import 'package:afyakit/features/inventory/batches/inventory_batch.dart';
import 'package:afyakit/features/inventory/batches/inventory_batches_providers.dart';
import 'package:afyakit/features/inventory/locations/inventory_locations_providers.dart';
import 'package:afyakit/features/inventory/records/cart/inventory_cart_providers.dart';
import 'package:afyakit/features/inventory/records/cart/inventory_cart_drawer.dart';
import 'package:afyakit/features/inventory/batches/inventory_batches_screen.dart';
import 'inventory_view.dart';
import 'inventory_views_providers.dart';
import 'inventory_item_tile.dart';

/// Stock browser. For Stock In, create batches only against an active delivery
/// session; the dedicated Deliveries screen owns session creation/finalization.
/// For Stock Out, the local Cart stages issue requests; execution is backend-only.
class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key, required this.mode, required this.appId});
  final InventoryMode mode;
  final String appId;

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  String? selectedStore;
  String? selectedType;
  String query = '';

  @override
  Widget build(BuildContext context) {
    final storesAsync = ref.watch(inventoryLocationsProvider(null));
    final typesAsync = ref.watch(itemTypesProvider);
    final cart = ref.watch(inventoryCartProvider);
    final stores = storesAsync.valueOrNull ?? const [];
    final types = typesAsync.valueOrNull ?? const [];
    final currentStore =
        stores.any((store) => store.id == selectedStore && !store.isArchived)
        ? selectedStore
        : null;
    final currentType =
        types.any((type) => type.typeId == selectedType && type.isActive)
        ? selectedType
        : (types.where((type) => type.isActive).firstOrNull?.typeId);
    final batchesAsync = ref.watch(inventoryBatchesProvider(currentStore));
    final itemAsync = currentType == null
        ? null
        : ref.watch(inventoryViewItemsProvider(currentType));
    final batchList = batchesAsync.valueOrNull ?? const <InventoryBatch>[];
    final batchesByItem = <String, List<InventoryBatch>>{};
    if (currentStore != null) {
      for (final batch in batchList) {
        if (batch.storeId != currentStore || batch.isArchived) continue;
        batchesByItem.putIfAbsent(batch.itemId, () => []).add(batch);
      }
    }

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: Text(widget.mode.label),
        actions: [
          if (widget.mode.isStockOut)
            IconButton(
              tooltip: 'Issue cart (${cart.totalQuantity})',
              icon: Badge(
                isLabelVisible: cart.totalQuantity > 0,
                label: Text('${cart.totalQuantity}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(inventoryLocationsProvider(null));
              ref.invalidate(itemTypesProvider);
              ref.invalidate(inventoryBatchesProvider(currentStore));
              if (currentType != null) {
                ref.invalidate(inventoryViewItemsProvider(currentType));
              }
            },
          ),
        ],
      ),
      endDrawer: widget.mode.isStockOut ? const InventoryCartDrawer() : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.mode.isStockIn)
            Card(
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Inventory Items'),
                subtitle: const Text('Add, edit and manage catalogue items'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const InventoryItemsScreen(),
                    ),
                  );

                  if (!mounted) return;

                  ref.invalidate(itemTypesProvider);

                  final typeId = selectedType;
                  if (typeId != null) {
                    ref.invalidate(inventoryViewItemsProvider(typeId));
                  }
                },
              ),
            ),
          if (widget.mode.isStockIn)
            Card(
              child: ListTile(
                title: const Text('Manage batches'),
                subtitle: const Text(
                  'Use an active delivery session ID when receiving stock.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const InventoryBatchesScreen(),
                  ),
                ),
              ),
            ),
          storesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Store lookup failed: $error'),
            data: (_) => DropdownButtonFormField<String>(
              key: ValueKey(currentStore),
              initialValue: currentStore,
              decoration: const InputDecoration(labelText: 'Store'),
              items: [
                for (final store in stores.where((s) => !s.isArchived))
                  DropdownMenuItem(value: store.id, child: Text(store.name)),
              ],
              onChanged: (value) => setState(() => selectedStore = value),
            ),
          ),
          const SizedBox(height: 12),
          typesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Item type lookup failed: $error'),
            data: (_) => DropdownButtonFormField<String>(
              key: ValueKey(currentType),
              initialValue: currentType,
              decoration: const InputDecoration(labelText: 'Item type'),
              items: [
                for (final type in types.where((t) => t.isActive))
                  DropdownMenuItem(value: type.typeId, child: Text(type.label)),
              ],
              onChanged: (value) => setState(() => selectedType = value),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search items',
            ),
            onChanged: (value) =>
                setState(() => query = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 12),
          if (currentStore == null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Select a store to view its batches.'),
            )
          else if (batchesAsync.isLoading || itemAsync?.isLoading == true)
            const Center(child: CircularProgressIndicator())
          else if (batchesAsync.hasError || itemAsync?.hasError == true)
            Text(
              'Unable to load inventory: ${batchesAsync.error ?? itemAsync?.error}',
            )
          else if (itemAsync == null)
            const Text('No configured item types.')
          else ...[
            for (final item in itemAsync.valueOrNull ?? const [])
              if (!item.isArchived &&
                  (query.isEmpty ||
                      '${item.name} ${item.id} ${item.group ?? ''}'
                          .toLowerCase()
                          .contains(query)))
                InventoryItemTile(
                  key: ValueKey(item.id),
                  item: item,
                  batches: batchesByItem[item.id] ?? const [],
                  locations: stores,
                  stockOut: widget.mode.isStockOut,
                  onSelectBatch: (batch) => _selectBatch(batch),
                ),
          ],
        ],
      ),
    );
  }

  Future<void> _selectBatch(InventoryBatch batch) async {
    final available = batch.quantity;
    final input = TextEditingController(text: '1');
    try {
      final quantity = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Select quantity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Recorded balance: $available'),
              TextField(
                controller: input,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(input.text.trim());
                if (value == null || value < 1 || value > available) return;
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Add to cart'),
            ),
          ],
        ),
      );
      if (quantity == null || !mounted) return;
      ref.read(inventoryCartProvider.notifier).select(batch, quantity);
      scaffoldKey.currentState?.openEndDrawer();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      input.dispose();
    }
  }
}
