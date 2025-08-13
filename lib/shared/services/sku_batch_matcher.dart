import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/features/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/shared/utils/normalize/normalize_string.dart';

class SkuBatchMatcher {
  final Map<String, List<BatchRecord>> _batchesBySku;
  final Map<String, BaseInventoryItem> _itemsById;
  final Map<String, Map<String, List<BatchRecord>>> _batchesByStoreBySku;
  final Map<String, String> _batchIdToSku;

  // ─────────────────────────────────────────────
  // ✅ Constructor + Factory
  SkuBatchMatcher._internal({
    required Map<String, List<BatchRecord>> batchesBySku,
    required Map<String, BaseInventoryItem> itemsById,
    required Map<String, Map<String, List<BatchRecord>>> batchesByStoreBySku,
    required Map<String, String> batchIdToSku,
  }) : _batchesBySku = batchesBySku,
       _itemsById = itemsById,
       _batchesByStoreBySku = batchesByStoreBySku,
       _batchIdToSku = batchIdToSku;

  factory SkuBatchMatcher.from({
    required List<BaseInventoryItem> items,
    required List<BatchRecord> batches,
  }) {
    final normalizedItems = <String, BaseInventoryItem>{};
    for (final item in items) {
      final id = item.id?.normalize();
      if (id != null && id.isNotEmpty) {
        normalizedItems[id] = item;
      }
    }

    final batchesBySku = <String, List<BatchRecord>>{};
    final batchesByStoreBySku = <String, Map<String, List<BatchRecord>>>{};
    final batchIdToSku = <String, String>{};

    for (final batch in batches) {
      final itemId = batch.itemId.normalize();
      final item = normalizedItems[itemId];
      if (item == null) continue;

      batchesBySku.putIfAbsent(itemId, () => []).add(batch);

      final storeId = batch.storeId.normalize();
      if (storeId.isNotEmpty && storeId != 'null') {
        batchesByStoreBySku
            .putIfAbsent(itemId, () => {})
            .putIfAbsent(storeId, () => [])
            .add(batch);
      }

      batchIdToSku[batch.id] = itemId;
    }

    return SkuBatchMatcher._internal(
      batchesBySku: batchesBySku,
      itemsById: normalizedItems,
      batchesByStoreBySku: batchesByStoreBySku,
      batchIdToSku: batchIdToSku,
    );
  }

  // ─────────────────────────────────────────────
  // 📦 Batch & Item Lookups

  List<BatchRecord> getBatches(String itemId) =>
      _batchesBySku[itemId.normalize()] ?? [];

  List<BatchRecord> getBatchesForItem(BaseInventoryItem item) {
    final id = item.id;
    return (id == null || id.isEmpty)
        ? []
        : _batchesBySku[id.normalize()] ?? [];
  }

  Map<String, List<BatchRecord>> getBatchesByStoreForItem(
    BaseInventoryItem item,
  ) {
    final id = item.id;
    return (id == null || id.isEmpty)
        ? {}
        : _batchesByStoreBySku[id.normalize()] ?? {};
  }

  BaseInventoryItem? getItem(String itemId) => _itemsById[itemId.normalize()];

  BaseInventoryItem? getItemForBatch(String batchId) {
    final itemId = _batchIdToSku[batchId];
    return itemId == null ? null : getItem(itemId);
  }

  String getDisplayName(String itemId) => getItem(itemId)?.name ?? 'Unknown';

  bool hasBatchesFor(String itemId) =>
      _batchesBySku.containsKey(itemId.normalize());

  Map<String, List<BatchRecord>> get map => _batchesBySku;
}
