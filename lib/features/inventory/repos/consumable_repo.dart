import 'package:afyakit/features/inventory/models/items/consumable_item.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';

class ConsumableRepo {
  Future<List<ConsumableItem>> fetch(String tenantId) async {
    final snapshot = await db
        .collection('tenants')
        .doc(tenantId)
        .collection('consumables')
        .get();

    return snapshot.docs
        .map((doc) => ConsumableItem.fromMap(doc.id, doc.data()))
        .toList();
  }
}
