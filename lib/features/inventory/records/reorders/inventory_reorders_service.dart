import 'package:afyakit/features/inventory/items/inventory_item.dart';
import 'package:afyakit/features/inventory/items/inventory_items_service.dart';
import 'inventory_reorder.dart';

/// Fetches canonical items and exports proposals. Does not invent a reorder API.
class InventoryReordersService {
  const InventoryReordersService(this.itemsService);

  final InventoryItemsService itemsService;

  Future<List<InventoryItem>> listOrderableItems() async {
    const pageSize = 100;
    final all = <InventoryItem>[];
    var page = 1;
    while (true) {
      final result = await itemsService.list(page: page, perPage: pageSize);
      all.addAll(result.items.where((item) =>
          !item.isArchived && item.id.isNotEmpty && item.itemType.isNotEmpty));
      if (!result.hasMore) break;
      if (result.page < page) {
        throw StateError('Inventory pagination did not advance.');
      }
      page = result.page + 1;
      if (page > 10000) throw StateError('Inventory pagination exceeded safety limit.');
    }
    all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return all;
  }

  /// CSV suitable for saving into a .csv file. No Firestore writes.
  String toCsv(InventoryReorderDraft draft) {
    String cell(Object? value) => '"${(value ?? '').toString().replaceAll('"', '""')}"';
    final rows = <List<Object?>>[
      ['item_id', 'item_type', 'name', 'quantity', 'note'],
      for (final line in draft.sortedLines)
        [line.itemId, line.itemType, line.name, line.quantity, draft.note],
    ];
    return rows.map((row) => row.map(cell).join(',')).join('\r\n');
  }
}
