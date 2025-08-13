import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';

class BatchRepo {
  Future<List<BatchRecord>> fetch(String tenantId) async {
    final snapshot = await db.collectionGroup('batches').get();

    // Filter batches that belong to this tenant
    final filtered = snapshot.docs.where((doc) {
      final path = doc.reference.path;
      return path.contains('tenants/$tenantId/stores/');
    });

    return filtered.map((doc) => BatchRecord.fromSnapshot(doc)).toList();
  }
}
