//lib/features/inventory/models/item_type_enum.dart

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
