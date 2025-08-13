//lib/shared/providers/streams/consumable_items_stream_provider.dart

import 'package:afyakit/features/inventory/models/items/consumable_item.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final consumableItemsStreamProvider = StreamProvider.autoDispose
    .family<List<ConsumableItem>, String>((ref, tenantId) {
      final query = db.collection('tenants/$tenantId/consumables');

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => ConsumableItem.fromDoc(doc)).toList();
      });
    });
