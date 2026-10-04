import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/inventory/records/deliveries/controllers/delivery_session_engine.dart';
import 'package:afyakit/features/inventory/records/deliveries/models/delivery_record.dart';
import 'package:afyakit/features/inventory/records/deliveries/services/delivery_session_service.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final deliveryRecordProvider = FutureProvider.autoDispose
    .family<DeliveryRecord, String>((ref, deliveryId) async {
      final tenantId = ref.watch(tenantIdProvider);
      final service = ref.read(deliverySessionServiceProvider);

      return service.getDelivery(tenantId: tenantId, deliveryId: deliveryId);
    });

final deliveryBannerVisibleProvider = Provider.autoDispose<bool>((ref) {
  final session = ref.watch(deliverySessionEngineProvider);

  final deliveryId = session.deliveryId?.trim() ?? '';

  return deliveryId.isNotEmpty;
});

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
