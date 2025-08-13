//lib/shared/providers/streams/equipment_items_stream_provider.dart

import 'package:afyakit/features/inventory/models/items/equipment_item.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final equipmentItemsStreamProvider = StreamProvider.autoDispose
    .family<List<EquipmentItem>, String>((ref, tenantId) {
      final query = db.collection('tenants/$tenantId/equipments');

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => EquipmentItem.fromDoc(doc)).toList();
      });
    });
