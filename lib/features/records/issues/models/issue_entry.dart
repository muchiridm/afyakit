import 'package:afyakit/features/inventory/models/item_type_enum.dart';

class IssueEntry {
  final String id;
  final String itemId;
  final ItemType itemType;
  final String itemName;
  final String itemGroup;
  final String? strength;
  final String? size;
  final String? formulation;
  final String? packSize;
  final String itemTypeLabel;
  final String? batchId;
  final int quantity;

  IssueEntry({
    required this.id,
    required this.itemId,
    required this.itemType,
    required this.itemName,
    required this.itemGroup,
    this.strength,
    this.size,
    this.formulation,
    this.packSize,
    required this.itemTypeLabel,
    this.batchId,
    required this.quantity,
  }) : assert(itemId.trim().isNotEmpty, '❌ itemId cannot be empty');

  // 🔄 Deserialize
  factory IssueEntry.fromMap(String id, Map<String, dynamic> map) {
    final itemId = map['itemId']?.toString().trim();
    if (itemId == null || itemId.isEmpty) {
      throw Exception('❌ Missing or empty itemId in IssueEntry $id');
    }

    return IssueEntry(
      id: id,
      itemId: itemId,
      itemType: ItemType.fromString(map['itemType'] ?? ''),
      itemName: map['itemName'] ?? 'Unknown Item',
      itemGroup: map['itemGroup'] ?? 'Unknown Group',
      strength: map['strength'],
      size: map['size'],
      formulation: map['formulation'],
      packSize: map['packSize'],
      itemTypeLabel: map['itemTypeLabel'] ?? map['itemType'] ?? '',
      batchId: map['batchId'],
      quantity: map['quantity'] ?? 0,
    );
  }

  // 🧾 Serialize
  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'itemType': itemType.key,
    'itemName': itemName,
    'itemGroup': itemGroup,
    'strength': strength,
    'size': size,
    'formulation': formulation,
    'packSize': packSize,
    'itemTypeLabel': itemTypeLabel,
    'batchId': batchId,
    'quantity': quantity,
  };

  // 🧪 Factory from inventory item and batch
  static IssueEntry fromItemAndBatch({
    required String id,
    required String itemId,
    required String itemName,
    required ItemType itemType,
    required String itemGroup,
    String? strength,
    String? size,
    String? formulation,
    String? packSize,
    required String itemTypeLabel,
    required String batchId,
    required int quantity,
  }) {
    return IssueEntry(
      id: id,
      itemId: itemId,
      itemType: itemType,
      itemName: itemName,
      itemGroup: itemGroup,
      strength: strength,
      size: size,
      formulation: formulation,
      packSize: packSize,
      itemTypeLabel: itemTypeLabel,
      batchId: batchId,
      quantity: quantity,
    );
  }

  // 🔁 Clone with changes
  IssueEntry copyWith({
    String? id,
    String? itemId,
    ItemType? itemType,
    String? itemName,
    String? itemGroup,
    String? strength,
    String? size,
    String? formulation,
    String? packSize,
    String? itemTypeLabel,
    String? batchId,
    int? quantity,
  }) {
    final newItemId = itemId?.trim();
    if (newItemId != null && newItemId.isEmpty) {
      throw Exception('❌ itemId cannot be empty in copyWith()');
    }

    return IssueEntry(
      id: id ?? this.id,
      itemId: newItemId ?? this.itemId,
      itemType: itemType ?? this.itemType,
      itemName: itemName ?? this.itemName,
      itemGroup: itemGroup ?? this.itemGroup,
      strength: strength ?? this.strength,
      size: size ?? this.size,
      formulation: formulation ?? this.formulation,
      packSize: packSize ?? this.packSize,
      itemTypeLabel: itemTypeLabel ?? this.itemTypeLabel,
      batchId: batchId ?? this.batchId,
      quantity: quantity ?? this.quantity,
    );
  }

  // ✅ Quick validation helper
  bool get isValid => itemId.trim().isNotEmpty && quantity > 0;

  @override
  String toString() => '📦 $itemName (Qty: $quantity, Batch: $batchId)';
}
