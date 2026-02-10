import 'package:afyakit/shared/utils/parse/primitives.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afyakit/features/inventory/items/models/items/base_inventory_item.dart';
import 'package:afyakit/features/inventory/items/extensions/item_type_x.dart';

class ConsumableItem implements BaseInventoryItem {
  // ─────────────────────────────────────────────────────────────
  // 🆔 Core fields (inherited)
  // ─────────────────────────────────────────────────────────────
  @override
  final String? id;

  @override
  final String name;

  @override
  final String group;

  @override
  final int? reorderLevel;

  @override
  final int? proposedOrder;

  @override
  final ItemType type = ItemType.consumable;

  @override
  ItemType get itemType => type;

  @override
  String get storeId => group;

  // ─────────────────────────────────────────────────────────────
  // 📦 Extra metadata
  // ─────────────────────────────────────────────────────────────
  final String? brandName;
  final String? description;
  final String? size;
  final String? packSize;
  final String? unit;
  final String? package;

  // ─────────────────────────────────────────────────────────────
  // 🔍 Search index
  // ─────────────────────────────────────────────────────────────
  @override
  List<String?> get searchTerms => [
    name,
    group,
    brandName,
    description,
    size,
    unit,
    package,
  ];

  // ─────────────────────────────────────────────────────────────
  // 🏗 Constructor
  // ─────────────────────────────────────────────────────────────
  const ConsumableItem({
    this.id,
    required this.name,
    required this.group,
    this.reorderLevel,
    this.proposedOrder,
    this.brandName,
    this.description,
    this.size,
    this.packSize,
    this.unit,
    this.package,
  });

  // ─────────────────────────────────────────────────────────────
  // 🔁 Factories
  // ─────────────────────────────────────────────────────────────

  factory ConsumableItem.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return ConsumableItem.fromMap(doc.id, map);
  }

  factory ConsumableItem.fromMap(String id, Map<String, dynamic> map) {
    final rawType = map['itemType'];
    if (rawType != ItemType.consumable.name) {
      throw Exception('❌ Invalid or missing itemType for ConsumableItem [$id]');
    }

    return ConsumableItem(
      id: id,
      name: map['name'] ?? map['genericName'] ?? '',
      group: map['group'] ?? '',
      brandName: map['brandName'],
      description: map['description'],
      size: map['size'],
      packSize: map['packSize'],
      unit: map['unit'],
      package: map['package'],
      reorderLevel: asIntOrNull(map['reorderLevel']),
      proposedOrder: asIntOrNull(map['proposedOrder']),
    );
  }

  factory ConsumableItem.blank() => const ConsumableItem(
    name: 'Unknown Consumable',
    group: 'Unknown Group',
    brandName: '',
    description: '',
    size: '',
    packSize: '',
    unit: '',
    package: '',
    reorderLevel: 0,
    proposedOrder: 0,
  );

  // ─────────────────────────────────────────────────────────────
  // 🔄 Copy & Map
  // ─────────────────────────────────────────────────────────────

  @override
  ConsumableItem copyWith({
    String? id,
    String? name,
    String? group,
    String? brandName,
    String? description,
    String? size,
    String? packSize,
    String? unit,
    String? package,
    int? reorderLevel,
    int? proposedOrder,
  }) {
    return ConsumableItem(
      id: id ?? this.id,
      name: name ?? this.name,
      group: group ?? this.group,
      brandName: brandName ?? this.brandName,
      description: description ?? this.description,
      size: size ?? this.size,
      packSize: packSize ?? this.packSize,
      unit: unit ?? this.unit,
      package: package ?? this.package,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      proposedOrder: proposedOrder ?? this.proposedOrder,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'name': name,
    'group': group,
    'brandName': brandName,
    'description': description,
    'size': size,
    'packSize': packSize,
    'unit': unit,
    'package': package,
    'reorderLevel': reorderLevel,
    'proposedOrder': proposedOrder,
    'itemType': type.name,
  };

  @override
  ConsumableItem copyWithFromMap(Map<String, dynamic> fields) {
    return ConsumableItem(
      id: fields['id'] ?? id,
      name: fields['name'] ?? name,
      group: fields['group'] ?? group,
      brandName: fields['brandName'] ?? brandName,
      description: fields['description'] ?? description,
      size: fields['size'] ?? size,
      packSize: fields['packSize'] ?? packSize,
      unit: fields['unit'] ?? unit,
      package: fields['package'] ?? package,
      reorderLevel: fields['reorderLevel'] ?? reorderLevel,
      proposedOrder: fields['proposedOrder'] ?? proposedOrder,
    );
  }
}
