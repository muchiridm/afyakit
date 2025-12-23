import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afyakit/features/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/features/inventory/items/models/items/base_inventory_item.dart';
import 'package:afyakit/shared/utils/parsers/parse_ToStringList.dart';
import 'package:afyakit/shared/utils/parsers/parse_nullable_int.dart';

class MedicationItem implements BaseInventoryItem {
  // ─────────────────────────────────────────────
  // 🔹 BaseInventoryItem Fields
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
  final ItemType type = ItemType.medication;

  @override
  ItemType get itemType => type;

  @override
  String get storeId => group;

  @override
  List<String?> get searchTerms => [
    name,
    group,
    brandName,
    strength,
    size,
    formulation,
  ];

  // ─────────────────────────────────────────────
  // 💊 Medication-Specific Fields
  // ─────────────────────────────────────────────
  final String? brandName;
  final String? strength;
  final String? size;
  final List<String>? route;
  final String? formulation;
  final String? packSize;

  // ─────────────────────────────────────────────
  // 🛠 Constructor
  // ─────────────────────────────────────────────
  const MedicationItem({
    this.id,
    required this.name,
    required this.group,
    this.brandName,
    this.strength,
    this.size,
    this.route,
    this.formulation,
    this.packSize,
    this.reorderLevel,
    this.proposedOrder,
  });

  // ─────────────────────────────────────────────
  // 🔁 Factories
  // ─────────────────────────────────────────────
  factory MedicationItem.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return MedicationItem.fromMap(doc.id, map);
  }

  factory MedicationItem.fromMap(String id, Map<String, dynamic> map) {
    final rawType = map['itemType'];
    if (rawType != ItemType.medication.name) {
      throw Exception('❌ Invalid or missing itemType for MedicationItem [$id]');
    }

    return MedicationItem(
      id: id,
      name: map['name'] ?? map['genericName'] ?? '',
      group: map['group'] ?? '',
      brandName: map['brandName'],
      strength: map['strength'],
      size: map['size'],
      route: parseToStringList(map['route']),
      formulation: map['formulation'],
      packSize: map['packSize'],
      reorderLevel: parseNullableInt(map['reorderLevel']),
      proposedOrder: parseNullableInt(map['proposedOrder']),
    );
  }

  // ─────────────────────────────────────────────
  // 🧭 Blank Default
  // ─────────────────────────────────────────────
  factory MedicationItem.blank() => const MedicationItem(
    id: null,
    name: 'Unknown Medication',
    group: 'Unknown Group',
    brandName: '',
    strength: '',
    size: '',
    route: [],
    formulation: '',
    packSize: '',
    reorderLevel: 0,
    proposedOrder: 0,
  );

  // ─────────────────────────────────────────────
  // 🔄 Copy + Map
  // ─────────────────────────────────────────────
  @override
  MedicationItem copyWith({
    String? id,
    String? name,
    String? group,
    String? brandName,
    String? strength,
    String? size,
    List<String>? route,
    String? formulation,
    String? packSize,
    int? reorderLevel,
    int? proposedOrder,
  }) {
    return MedicationItem(
      id: id ?? this.id,
      name: name ?? this.name,
      group: group ?? this.group,
      brandName: brandName ?? this.brandName,
      strength: strength ?? this.strength,
      size: size ?? this.size,
      route: route ?? this.route,
      formulation: formulation ?? this.formulation,
      packSize: packSize ?? this.packSize,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      proposedOrder: proposedOrder ?? this.proposedOrder,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'name': name,
    'group': group,
    'brandName': brandName,
    'strength': strength,
    'size': size,
    'route': route,
    'formulation': formulation,
    'packSize': packSize,
    'reorderLevel': reorderLevel,
    'proposedOrder': proposedOrder,
    'itemType': type.name,
  };

  @override
  MedicationItem copyWithFromMap(Map<String, dynamic> fields) {
    return MedicationItem(
      id: fields['id'] ?? id,
      name: fields['name'] ?? name,
      group: fields['group'] ?? group,
      brandName: fields['brandName'] ?? brandName,
      strength: fields['strength'] ?? strength,
      size: fields['size'] ?? size,
      route: parseToStringList(fields['route']) ?? route,
      formulation: fields['formulation'] ?? formulation,
      packSize: fields['packSize'] ?? packSize,
      reorderLevel: fields['reorderLevel'] ?? reorderLevel,
      proposedOrder: fields['proposedOrder'] ?? proposedOrder,
    );
  }
}
