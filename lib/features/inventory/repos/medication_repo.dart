import 'package:afyakit/features/inventory/models/items/medication_item.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';

class MedicationRepo {
  Future<List<MedicationItem>> fetch(String tenantId) async {
    final snapshot = await db
        .collection('tenants')
        .doc(tenantId)
        .collection('medications')
        .get();

    return snapshot.docs
        .map((doc) => MedicationItem.fromMap(doc.id, doc.data()))
        .toList();
  }
}
