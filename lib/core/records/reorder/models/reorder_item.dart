import 'package:afyakit/core/inventory/models/item_type_enum.dart';

class ReorderItem {
  final String itemId;
  final ItemType itemType;
  final int quantity;

  ReorderItem({
    required this.itemId,
    required this.itemType,
    required this.quantity,
  });

  factory ReorderItem.fromMap(Map<String, dynamic> map) {
    return ReorderItem(
      itemId: map['itemId'] as String,
      itemType: ItemType.fromString(map['itemType'] as String),
      quantity: map['quantity'] as int,
    );
  }
}
