import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afyakit/core/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/core/inventory/models/item_type_enum.dart';
import 'package:afyakit/shared/utils/parsers/parse_nullable_int.dart';

class EquipmentItem implements BaseInventoryItem {
  // ─────────────────────────────────────────────
  // 🧩 Required fields (BaseInventoryItem)
  // ─────────────────────────────────────────────
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
  final ItemType type = ItemType.equipment;

  @override
  ItemType get itemType => type;

  @override
  String get storeId => group; // 🔥 TEMP fallback — override properly if needed

  // ─────────────────────────────────────────────
  // 🧾 Additional equipment metadata
  // ─────────────────────────────────────────────
  final String? description;
  final String? model;
  final String? manufacturer;
  final String? serialNumber;
  final String? package;

  // ─────────────────────────────────────────────
  // 🔍 Search terms
  // ─────────────────────────────────────────────
  @override
  List<String?> get searchTerms => [
    name,
    group,
    description,
    model,
    manufacturer,
    serialNumber,
    package,
  ];

  // ─────────────────────────────────────────────
  // 🛠 Constructor
  // ─────────────────────────────────────────────
  const EquipmentItem({
    this.id,
    required this.name,
    required this.group,
    this.description,
    this.model,
    this.manufacturer,
    this.serialNumber,
    this.package,
    this.reorderLevel,
    this.proposedOrder,
  });

  // ─────────────────────────────────────────────
  // 🔁 Factories
  // ─────────────────────────────────────────────
  factory EquipmentItem.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return EquipmentItem.fromMap(doc.id, map);
  }

  factory EquipmentItem.fromMap(String id, Map<String, dynamic> map) {
    final rawType = map['itemType'];
    if (rawType != ItemType.equipment.name) {
      throw Exception('❌ Invalid or missing itemType for EquipmentItem [$id]');
    }

    return EquipmentItem(
      id: id,
      name: map['name'] ?? '',
      group: map['group'] ?? '',
      description: map['description'],
      model: map['model'],
      manufacturer: map['manufacturer'],
      serialNumber: map['serialNumber'],
      package: map['package'],
      reorderLevel: parseNullableInt(map['reorderLevel']),
      proposedOrder: parseNullableInt(map['proposedOrder']),
    );
  }

  static EquipmentItem blank() => const EquipmentItem(
    name: 'Unknown Equipment',
    group: 'Unknown Group',
    description: '',
    model: '',
    manufacturer: '',
    serialNumber: '',
    package: '',
    reorderLevel: 0,
    proposedOrder: 0,
  );

  // ─────────────────────────────────────────────
  // 🔄 Copy + Map
  // ─────────────────────────────────────────────
  @override
  EquipmentItem copyWith({
    String? id,
    String? name,
    String? group,
    String? description,
    String? model,
    String? manufacturer,
    String? serialNumber,
    String? package,
    int? reorderLevel,
    int? proposedOrder,
  }) {
    return EquipmentItem(
      id: id ?? this.id,
      name: name ?? this.name,
      group: group ?? this.group,
      description: description ?? this.description,
      model: model ?? this.model,
      manufacturer: manufacturer ?? this.manufacturer,
      serialNumber: serialNumber ?? this.serialNumber,
      package: package ?? this.package,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      proposedOrder: proposedOrder ?? this.proposedOrder,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'name': name,
    'group': group,
    'description': description,
    'model': model,
    'manufacturer': manufacturer,
    'serialNumber': serialNumber,
    'package': package,
    'reorderLevel': reorderLevel,
    'proposedOrder': proposedOrder,
    'itemType': type.name,
  };

  @override
  EquipmentItem copyWithFromMap(Map<String, dynamic> fields) {
    return EquipmentItem(
      id: fields['id'] ?? id,
      name: fields['name'] ?? name,
      group: fields['group'] ?? group,
      description: fields['description'] ?? description,
      model: fields['model'] ?? model,
      manufacturer: fields['manufacturer'] ?? manufacturer,
      serialNumber: fields['serialNumber'] ?? serialNumber,
      package: fields['package'] ?? package,
      reorderLevel: fields['reorderLevel'] ?? reorderLevel,
      proposedOrder: fields['proposedOrder'] ?? proposedOrder,
    );
  }
}
