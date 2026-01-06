// lib/core/inventory/extensions/item_type_enum.dart
import 'package:afyakit/features/inventory/items/models/items/base_inventory_item.dart';

enum ItemType {
  medication,
  consumable,
  equipment,
  unknown;

  String get key => name;

  String get label => switch (this) {
    ItemType.medication => 'Medication',
    ItemType.consumable => 'Consumable',
    ItemType.equipment => 'Equipment',
    ItemType.unknown => 'Unknown',
  };

  static ItemType fromString(String value) {
    return ItemType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ItemType.unknown,
    );
  }
}

/// Global helpers to keep API params / filters consistent everywhere.
extension ItemTypeX on ItemType {
  String get apiName => switch (this) {
    ItemType.medication => 'medication',
    ItemType.consumable => 'consumable',
    ItemType.equipment => 'equipment',
    ItemType.unknown => 'unknown',
  };

  bool get isConcrete => this != ItemType.unknown;

  static List<ItemType> get searchable => const [
    ItemType.medication,
    ItemType.consumable,
    ItemType.equipment,
  ];

  static ItemType fromApi(String? v) =>
      v == null ? ItemType.unknown : ItemType.fromString(v);

  String? get apiParamOrNull => isConcrete ? apiName : null;

  /// NEW: Best-effort inference from a model instance.
  /// - If model.type is set → use it
  /// - Otherwise, infer from runtimeType name (Medication/Consumable/Equipment)
  static ItemType inferFromModel(BaseInventoryItem item) {
    if (item.type != ItemType.unknown) return item.type;

    final rt = item.runtimeType.toString().toLowerCase();
    if (rt.contains('medication')) return ItemType.medication;
    if (rt.contains('consumable')) return ItemType.consumable;
    if (rt.contains('equipment')) return ItemType.equipment;

    return ItemType.unknown;
  }
}
