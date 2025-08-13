//lib/shared/providers/streams/batch_records_stream_provider.dart

import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final batchRecordsStreamProvider = StreamProvider.autoDispose
    .family<List<BatchRecord>, String>((ref, tenantId) {
      final firestore = db;

      return firestore.collectionGroup('batches').snapshots().map((snapshot) {
        final filteredDocs = snapshot.docs.where(
          (doc) => doc.reference.path.contains('tenants/$tenantId/stores/'),
        );

        return filteredDocs.map((doc) {
          return BatchRecord.fromSnapshot(doc);
        }).toList();
      });
    });
