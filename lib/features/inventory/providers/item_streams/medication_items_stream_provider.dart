//lib/shared/providers/streams/medication_items_stream_provider.dart

import 'package:afyakit/features/inventory/models/items/medication_item.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final medicationItemsStreamProvider = StreamProvider.autoDispose
    .family<List<MedicationItem>, String>((ref, tenantId) {
      final query = db.collection('tenants/$tenantId/medications');

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => MedicationItem.fromDoc(doc)).toList();
      });
    });
