import 'package:afyakit/core/inventory/models/item_type_enum.dart';

class CartDisplayItem {
  final String itemId;
  final String label;
  final ItemType itemType;
  final String subtitle;
  final List<CartDisplayBatch> batches;

  CartDisplayItem({
    required this.itemId,
    required this.label,
    required this.itemType,
    required this.subtitle,
    required this.batches,
  });
}

class CartDisplayBatch {
  final String batchId;
  final String label;
  final int quantity;
  final String storeId;

  CartDisplayBatch({
    required this.batchId,
    required this.label,
    required this.quantity,
    required this.storeId,
  });
}
