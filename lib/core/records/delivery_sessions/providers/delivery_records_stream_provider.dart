// library/shared/providers/inventory/delivery_records_stream_provider.dart

import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/records/delivery_sessions/models/delivery_record.dart';

final deliveryRecordsStreamProvider = StreamProvider.family
    .autoDispose<List<DeliveryRecord>, String>((ref, tenantId) {
      final snapshots = db
          .collection('tenants')
          .doc(tenantId)
          .collection('delivery_records')
          .orderBy('date', descending: true)
          .snapshots();

      return snapshots.map((snap) {
        return snap.docs
            .map((doc) => DeliveryRecord.fromMap(doc.id, doc.data()))
            .toList();
      });
    });
