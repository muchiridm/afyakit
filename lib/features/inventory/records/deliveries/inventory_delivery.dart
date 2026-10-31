class InventoryDeliveryBatch {
  const InventoryDeliveryBatch({required this.batchId, required this.itemId, required this.itemType, required this.itemName, required this.storeId, required this.quantity, this.source, this.batchNumber});
  final String batchId, itemId, itemType, itemName, storeId;
  final num quantity;
  final String? source, batchNumber;
  factory InventoryDeliveryBatch.fromJson(Map<String, dynamic> data) => InventoryDeliveryBatch(
    batchId: data['batch_id'] as String? ?? '', itemId: data['item_id'] as String? ?? '',
    itemType: data['item_type'] as String? ?? '', itemName: data['item_name'] as String? ?? '',
    storeId: data['store_id'] as String? ?? '', quantity: data['quantity'] as num? ?? 0,
    source: data['source'] as String?, batchNumber: data['batch_number'] as String?);
}

class InventoryDeliverySession {
  const InventoryDeliverySession({required this.deliveryId, required this.status, required this.sources, required this.storeIds, required this.batchesCount, this.lastStoreId, this.lastSource});
  final String deliveryId, status;
  final List<String> sources, storeIds;
  final int batchesCount;
  final String? lastStoreId, lastSource;
  factory InventoryDeliverySession.fromJson(Map<String, dynamic> data) => InventoryDeliverySession(
    deliveryId: data['delivery_id'] as String? ?? '', status: data['status'] as String? ?? '',
    sources: (data['sources'] as List? ?? const []).map((e) => e.toString()).toList(),
    storeIds: (data['store_ids'] as List? ?? const []).map((e) => e.toString()).toList(),
    batchesCount: (data['batches_count'] as num?)?.toInt() ?? 0,
    lastStoreId: data['last_store_id'] as String?, lastSource: data['last_source'] as String?);
}

class InventoryDelivery {
  const InventoryDelivery({required this.deliveryId, required this.sources, required this.storeIds, required this.totalItems, required this.totalQuantity, required this.batches, this.createdAt});
  final String deliveryId;
  final List<String> sources, storeIds;
  final int totalItems;
  final num totalQuantity;
  final List<InventoryDeliveryBatch> batches;
  final DateTime? createdAt;
  factory InventoryDelivery.fromJson(Map<String, dynamic> data) => InventoryDelivery(
    deliveryId: data['delivery_id'] as String? ?? '',
    sources: (data['sources'] as List? ?? const []).map((e) => e.toString()).toList(),
    storeIds: (data['store_ids'] as List? ?? const []).map((e) => e.toString()).toList(),
    totalItems: (data['total_items'] as num?)?.toInt() ?? 0,
    totalQuantity: data['total_quantity'] as num? ?? 0,
    batches: (data['batch_snapshots'] as List? ?? const []).map((e) => InventoryDeliveryBatch.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    createdAt: DateTime.tryParse(data['created_at'] as String? ?? ''));
}

class InventoryDeliveryReview {
  const InventoryDeliveryReview({required this.session, required this.batches, required this.totalItems, required this.totalQuantity});
  final InventoryDeliverySession session;
  final List<InventoryDeliveryBatch> batches;
  final int totalItems;
  final num totalQuantity;
  factory InventoryDeliveryReview.fromJson(Map<String, dynamic> data) => InventoryDeliveryReview(
    session: InventoryDeliverySession.fromJson(Map<String, dynamic>.from(data['session'] as Map)),
    batches: (data['batches'] as List? ?? const []).map((e) => InventoryDeliveryBatch.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    totalItems: (data['total_items'] as num?)?.toInt() ?? 0, totalQuantity: data['total_quantity'] as num? ?? 0);
}

class InventoryDeliveryPage {
  const InventoryDeliveryPage({required this.deliveries, required this.hasMore});
  final List<InventoryDelivery> deliveries;
  final bool hasMore;
}
