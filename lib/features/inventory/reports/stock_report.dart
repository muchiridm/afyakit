import 'package:afyakit/features/inventory/items/inventory_item.dart';
import 'package:afyakit/features/inventory/batches/inventory_batch.dart';
import 'package:afyakit/features/inventory/locations/inventory_location.dart';

/// Read-only snapshot: recorded balances, not an authoritative available-to-issue calculation.
class StockReport {
  const StockReport({required this.items, required this.batches, required this.locations});
  final List<InventoryItem> items;
  final List<InventoryBatch> batches;
  final List<InventoryLocation> locations;

  List<StockReportRow> get rows {
    final names = {for (final i in items) i.id: i};
    final stores = {for (final l in locations) l.id: l};
    final totals = <String, num>{};
    final counts = <String, int>{};
    for (final b in batches.where((b) => !b.isArchived)) {
      final key = '${b.storeId}\u0000${b.itemId}';
      totals[key] = (totals[key] ?? 0) + b.quantity;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final result = <StockReportRow>[];
    for (final entry in totals.entries) {
      final split = entry.key.split('\u0000');
      final storeId = split[0], itemId = split[1];
      final item = names[itemId];
      result.add(StockReportRow(
        itemId: itemId, itemName: item?.name ?? itemId,
        itemType: item?.itemType ?? 'unknown',
        storeId: storeId, storeName: stores[storeId]?.name ?? storeId,
        recordedQuantity: entry.value, batchCount: counts[entry.key] ?? 0,
        reorderLevel: item?.reorderLevel,
      ));
    }
    result.sort((a,b) { final c=a.storeName.compareTo(b.storeName); return c!=0 ? c : a.itemName.compareTo(b.itemName); });
    return result;
  }
}

class StockReportRow {
  const StockReportRow({required this.itemId,required this.itemName, required this.itemType,
    required this.storeId,required this.storeName,required this.recordedQuantity,
    required this.batchCount,this.reorderLevel});
  final String itemId, itemName, itemType, storeId, storeName;
  final num recordedQuantity;
  final int batchCount;
  final num? reorderLevel;
  bool get belowReorderLevel => reorderLevel != null && recordedQuantity < reorderLevel!;
}
