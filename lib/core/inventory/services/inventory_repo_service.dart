import 'package:afyakit/core/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/core/inventory/models/items/medication_item.dart';
import 'package:afyakit/core/inventory/models/items/consumable_item.dart';
import 'package:afyakit/core/inventory/models/items/equipment_item.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final inventoryRepoProvider = Provider<InventoryRepoService>((ref) {
  return InventoryRepoService();
});

class InventoryRepoService {
  Future<List<MedicationItem>> getMedications(String tenantId) async {
    final snapshot = await db
        .collection('tenants')
        .doc(tenantId)
        .collection('medications')
        .get();

    return snapshot.docs
        .map((doc) => MedicationItem.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<ConsumableItem>> getConsumables(String tenantId) async {
    final snapshot = await db
        .collection('tenants')
        .doc(tenantId)
        .collection('consumables')
        .get();

    return snapshot.docs
        .map((doc) => ConsumableItem.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<EquipmentItem>> getEquipments(String tenantId) async {
    final snapshot = await db
        .collection('tenants')
        .doc(tenantId)
        .collection('equipments') // ✅ consistent with your backend
        .get();

    return snapshot.docs
        .map((doc) => EquipmentItem.fromMap(doc.id, doc.data()))
        .toList();
  }
}

// ✅ Place extension OUTSIDE the class
extension InventoryRepoServiceX on InventoryRepoService {
  Future<Map<String, BaseInventoryItem>> fetchAllItemsAsMap(
    String tenantId,
  ) async {
    final meds = await getMedications(tenantId);
    final cons = await getConsumables(tenantId);
    final equip = await getEquipments(tenantId);

    final allItems = <BaseInventoryItem>[...meds, ...cons, ...equip];

    return {
      for (final item in allItems)
        if (item.id != null) item.id!: item,
    };
  }
}
