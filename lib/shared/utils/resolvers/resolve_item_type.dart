import 'package:afyakit/core/inventory/extensions/item_type_x.dart';
import 'package:afyakit/core/inventory/models/items/medication_item.dart';
import 'package:afyakit/core/inventory/models/items/consumable_item.dart';
import 'package:afyakit/core/inventory/models/items/equipment_item.dart';

ItemType resolveItemType(dynamic item, [ItemType fallback = ItemType.unknown]) {
  if (item is MedicationItem) return ItemType.medication;
  if (item is ConsumableItem) return ItemType.consumable;
  if (item is EquipmentItem) return ItemType.equipment;
  return fallback;
}
