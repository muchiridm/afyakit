import 'package:afyakit/core/auth_users/providers/auth_session/current_user_providers.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_type_enum.dart';
import 'package:afyakit/core/inventory_view/utils/inventory_mode_enum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/batches/models/batch_record.dart';
import 'package:afyakit/core/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/core/inventory/models/items/consumable_item.dart';
import 'package:afyakit/core/inventory/models/items/equipment_item.dart';
import 'package:afyakit/core/inventory/models/items/medication_item.dart';
import 'package:afyakit/core/inventory_view/widgets/inventory_item_tile_components/inventory_item_tile.dart';
import 'package:afyakit/core/inventory_view/utils/inventory_search_utils.dart';
import 'package:afyakit/core/inventory_view/controllers/inventory_view_controller.dart';
import 'package:afyakit/core/inventory_locations/inventory_location.dart';

class InventoryListView<T extends BaseInventoryItem> extends ConsumerWidget {
  final List<T> items;
  final Map<String, List<BatchRecord>> batchesBySku;
  final String query;
  final bool sortAscending;
  final InventoryMode mode;
  final bool enableSelectionCart;
  final Map<String, Map<String, int>>? batchQuantities;
  final void Function(String itemId, String batchId, int qty)? onQtyChange;
  final void Function(String itemId)? onAddToCart;

  const InventoryListView({
    super.key,
    required this.items,
    required this.batchesBySku,
    required this.query,
    required this.sortAscending,
    required this.mode,
    this.enableSelectionCart = false,
    this.batchQuantities,
    this.onQtyChange,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(
      inventoryLocationProvider(InventoryLocationType.store),
    );

    return storesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading stores: $e')),
      data: (stores) {
        final filtered =
            items
                .where((item) => item.id != null && matchesQuery(item, query))
                .toList()
              ..sort((a, b) {
                final aName = a.name.toLowerCase();
                final bName = b.name.toLowerCase();
                return sortAscending
                    ? aName.compareTo(bName)
                    : bName.compareTo(aName);
              });

        debugPrint('✅ Filtered item count: ${filtered.length}');

        if (filtered.isEmpty) {
          return const Center(child: Text('No items match your search.'));
        }

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final item = filtered[index];
            return _buildItemTile(
              context,
              ref,
              item,
              batchesBySku,
              batchQuantities,
              stores,
            );
          },
        );
      },
    );
  }

  Widget _buildItemTile(
    BuildContext context,
    WidgetRef ref,
    T item,
    Map<String, List<BatchRecord>> batchesBySku,
    Map<String, Map<String, int>>? batchQuantities,
    List<InventoryLocation> stores,
  ) {
    final itemId = item.id!;
    final itemBatches = batchesBySku[itemId] ?? [];
    final batchQty = batchQuantities?[itemId] ?? {};
    final user = ref.watch(currentUserProvider).asData?.value;

    void handleAddBatch() {
      if (user != null) {
        ref
            .read(inventoryViewControllerFamily(item.type).notifier)
            .startAddBatch(context, item, user);
      } else {
        debugPrint('❌ User not available for addBatch');
      }
    }

    if (item is MedicationItem) {
      return InventoryItemTile(
        key: ValueKey(itemId),
        item: item,
        group: item.group,
        name: item.name,
        brandName: item.brandName,
        strength: item.strength,
        size: item.size,
        formulation: item.formulation,
        route: item.route,
        packSize: item.packSize,
        batches: itemBatches,
        editable: !enableSelectionCart,
        selectable: enableSelectionCart,
        batchQuantities: batchQty,
        onBatchQtyChange: (batch, qty) =>
            onQtyChange?.call(itemId, batch.id, qty),
        onAddToCart: onAddToCart == null ? null : (_) => onAddToCart!(itemId),
        onAddBatch: handleAddBatch,
        mode: mode,
        stores: stores,
      );
    }

    if (item is ConsumableItem) {
      return InventoryItemTile(
        key: ValueKey(itemId),
        item: item,
        group: item.group,
        name: item.name,
        brandName: item.brandName,
        description: item.description,
        size: item.size,
        packSize: item.packSize,
        unit: item.unit,
        package: item.package,
        batches: itemBatches,
        editable: !enableSelectionCart,
        selectable: enableSelectionCart,
        batchQuantities: batchQty,
        onBatchQtyChange: (batch, qty) =>
            onQtyChange?.call(itemId, batch.id, qty),
        onAddToCart: onAddToCart == null ? null : (_) => onAddToCart!(itemId),
        onAddBatch: handleAddBatch,
        mode: mode,
        stores: stores,
      );
    }

    if (item is EquipmentItem) {
      return InventoryItemTile(
        key: ValueKey(itemId),
        item: item,
        group: item.group,
        name: item.name,
        brandName: item.manufacturer,
        description: item.description,
        packSize: item.model,
        unit: item.serialNumber,
        package: item.package,
        model: item.model,
        manufacturer: item.manufacturer,
        serialNumber: item.serialNumber,
        batches: itemBatches,
        editable: !enableSelectionCart,
        selectable: enableSelectionCart,
        batchQuantities: batchQty,
        onBatchQtyChange: (batch, qty) =>
            onQtyChange?.call(itemId, batch.id, qty),
        onAddToCart: onAddToCart == null ? null : (_) => onAddToCart!(itemId),
        onAddBatch: handleAddBatch,
        mode: mode,
        stores: stores,
      );
    }

    return const SizedBox();
  }
}
