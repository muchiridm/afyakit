class InventoryBatch {
  const InventoryBatch({required this.id, required this.itemId, required this.storeId,
    required this.itemType, required this.quantity, required this.isArchived,
    this.batchNumber, this.source, this.receivedDate, this.expiryDate,
    this.deliveryId, this.notes});

  final String id, itemId, storeId, itemType;
  final num quantity;
  final bool isArchived;
  final String? batchNumber, source, receivedDate, expiryDate, deliveryId, notes;

  factory InventoryBatch.fromJson(Map<String, dynamic> data) {
    String requiredText(String field) {
      final value = data[field];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Batch missing $field');
      }
      return value;
    }
    final quantity = data['quantity'];
    if (quantity is! num) throw const FormatException('Batch missing numeric quantity');
    return InventoryBatch(
      id: requiredText('batch_id'), itemId: requiredText('item_id'),
      storeId: requiredText('store_id'), itemType: requiredText('item_type'),
      quantity: quantity, isArchived: data['is_archived'] == true,
      batchNumber: data['batch_number'] as String?,
      source: data['source'] as String?,
      receivedDate: data['received_date'] as String?,
      expiryDate: data['expiry_date'] as String?,
      deliveryId: data['delivery_id'] as String?,
      notes: data['notes'] as String?,
    );
  }
}

class InventoryBatchInput {
  const InventoryBatchInput({required this.itemId, required this.storeId,
    required this.quantity, this.batchNumber, this.source,
    this.receivedDate, this.expiryDate, this.deliveryId, this.notes});
  final String itemId, storeId;
  final num quantity;
  final String? batchNumber, source, receivedDate, expiryDate, deliveryId, notes;

  Map<String, dynamic> toJson() => {
    'item_id': itemId, 'store_id': storeId, 'quantity': quantity,
    if (batchNumber?.trim().isNotEmpty == true) 'batch_number': batchNumber!.trim(),
    if (source?.trim().isNotEmpty == true) 'source': source!.trim(),
    if (receivedDate != null) 'received_date': receivedDate,
    if (expiryDate != null) 'expiry_date': expiryDate,
    if (deliveryId?.trim().isNotEmpty == true) 'delivery_id': deliveryId!.trim(),
    if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
  };
}

class InventoryBatchPage {
  const InventoryBatchPage({required this.batches, required this.page, required this.hasMore});
  final List<InventoryBatch> batches;
  final int page;
  final bool hasMore;
}
