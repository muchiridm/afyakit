// lib/core/inventory/extensions/item_type_enum.dart

enum ItemType {
  medication,
  consumable,
  equipment,
  unknown; // 👈 Fallback type for resilience

  String get key => name;

  String get label {
    switch (this) {
      case ItemType.medication:
        return 'Medication';
      case ItemType.consumable:
        return 'Consumable';
      case ItemType.equipment:
        return 'Equipment';
      case ItemType.unknown:
        return 'Unknown';
    }
  }

  static ItemType fromString(String value) {
    return ItemType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ItemType.unknown,
    );
  }
}

/// Global helpers to keep API params / filters consistent everywhere.
extension ItemTypeX on ItemType {
  /// API query value for this type (same as enum name for the 3 real types).
  String get apiName => switch (this) {
    ItemType.medication => 'medication',
    ItemType.consumable => 'consumable',
    ItemType.equipment => 'equipment',
    ItemType.unknown => 'unknown',
  };

  /// Whether this is a concrete inventory type (not the fallback).
  bool get isConcrete => this != ItemType.unknown;

  /// Nice list for “search across” loops.
  static List<ItemType> get searchable => const [
    ItemType.medication,
    ItemType.consumable,
    ItemType.equipment,
  ];

  /// Parse from an API string safely.
  static ItemType fromApi(String? v) =>
      v == null ? ItemType.unknown : ItemType.fromString(v);

  /// When you want a nullable API param: `type=...` or omit for unknown.
  String? get apiParamOrNull => isConcrete ? apiName : null;
}
