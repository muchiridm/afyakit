import 'package:afyakit/modules/inventory/items/models/items/equipment_item.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';

class EquipmentRepo {
  Future<List<EquipmentItem>> fetch(String tenantId) async {
    final snapshot = await db
        .collection('tenants')
        .doc(tenantId)
        .collection('equipments') // 🔥 intentionally using 'equipments'
        .get();

    return snapshot.docs
        .map((doc) => EquipmentItem.fromMap(doc.id, doc.data()))
        .toList();
  }
}
