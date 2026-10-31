import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/inventory/items/inventory_item.dart';
import 'package:afyakit/features/inventory/items/inventory_items_providers.dart';

/// Fetches all pages of the selected item type, not just page one.
/// Inventory item types themselves come from canonicalItemTypesProvider.
final inventoryViewItemsProvider = FutureProvider.autoDispose
    .family<List<InventoryItem>, String>((ref, typeId) async {
      final service = await ref.watch(inventoryItemsServiceProvider.future);
      final results = <InventoryItem>[];
      var page = 1;
      while (true) {
        final response = await service.list(typeId: typeId, page: page);
        results.addAll(response.items);
        if (!response.hasMore) break;
        if (response.page < page) {
          throw StateError('Inventory pagination did not advance');
        }
        page = response.page + 1;
      }
      return List.unmodifiable(results);
    });
