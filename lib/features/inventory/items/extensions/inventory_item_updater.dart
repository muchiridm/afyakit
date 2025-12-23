import 'package:afyakit/features/inventory/items/models/items/base_inventory_item.dart';
import 'package:afyakit/features/inventory/items/models/items/medication_item.dart';
import 'package:afyakit/features/inventory/items/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/items/models/items/equipment_item.dart';

extension InventoryItemUpdater on BaseInventoryItem {
  BaseInventoryItem applyFieldUpdates(Map<String, dynamic> fields) {
    return switch (this) {
      MedicationItem() => (this as MedicationItem).copyWith(
        packSize: fields['packSize']?.toString(),
        reorderLevel: _tryParseInt(fields['reorderLevel']),
        proposedOrder: _tryParseInt(fields['proposedOrder']),
      ),
      ConsumableItem() => (this as ConsumableItem).copyWith(
        packSize: fields['packSize']?.toString(),
        package: fields['package']?.toString(),
        reorderLevel: _tryParseInt(fields['reorderLevel']),
        proposedOrder: _tryParseInt(fields['proposedOrder']),
      ),
      EquipmentItem() => (this as EquipmentItem).copyWith(
        package: fields['package']?.toString(),
        reorderLevel: _tryParseInt(fields['reorderLevel']),
        proposedOrder: _tryParseInt(fields['proposedOrder']),
      ),
      _ => this,
    };
  }

  int? _tryParseInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    return int.tryParse(val.toString());
  }
}
