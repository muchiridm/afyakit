import '../models/items/medication_item.dart';
import '../models/items/consumable_item.dart';
import '../models/items/equipment_item.dart';
import '../models/items/base_inventory_item.dart';

class ItemResolver {
  static String? id(BaseInventoryItem item) => item.id;

  static String? name(BaseInventoryItem item) => item.name;

  static String? group(BaseInventoryItem item) => item.group;

  static int? reorderLevel(BaseInventoryItem item) => item.reorderLevel;

  static int? proposedOrder(BaseInventoryItem item) => item.proposedOrder;

  static String? brandName(BaseInventoryItem item) {
    if (item is MedicationItem) return item.brandName;
    if (item is ConsumableItem) return item.brandName;
    return null;
  }

  static String? description(BaseInventoryItem item) {
    if (item is ConsumableItem) return item.description;
    if (item is EquipmentItem) return item.description;
    if (item is MedicationItem) {
      return [
        item.brandName,
        item.strength,
        item.size,
        item.formulation,
      ].where((e) => e != null && e.trim().isNotEmpty).join(' • ');
    }
    return null;
  }

  static String? strength(BaseInventoryItem item) =>
      item is MedicationItem ? item.strength : null;

  static String? size(BaseInventoryItem item) {
    if (item is MedicationItem) return item.size;
    if (item is ConsumableItem) return item.size;
    return null;
  }

  static List<String>? route(BaseInventoryItem item) =>
      item is MedicationItem ? item.route : null;

  static String? formulation(BaseInventoryItem item) =>
      item is MedicationItem ? item.formulation : null;

  static String? packSize(BaseInventoryItem item) {
    if (item is MedicationItem) return item.packSize;
    if (item is ConsumableItem) return item.packSize;
    return null;
  }

  static String? unit(BaseInventoryItem item) =>
      item is ConsumableItem ? item.unit : null;

  static String? package(BaseInventoryItem item) {
    if (item is ConsumableItem) return item.package;
    if (item is EquipmentItem) return item.package;
    return null;
  }

  static String? model(BaseInventoryItem item) =>
      item is EquipmentItem ? item.model : null;

  static String? manufacturer(BaseInventoryItem item) =>
      item is EquipmentItem ? item.manufacturer : null;

  static String? serialNumber(BaseInventoryItem item) =>
      item is EquipmentItem ? item.serialNumber : null;
}
