import 'package:afyakit/modules/inventory/records/deliveries/providers/active_delivery_session_provider.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';

final deliveryBannerVisibleProvider = StreamProvider.autoDispose<bool>((ref) {
  final tenantId = ref.watch(tenantSlugProvider);
  final active$ = ref.watch(activeDeliverySessionProvider.stream);

  return active$.asyncMap((active) async {
    if (tenantId.isEmpty || active == null) return false;

    final deliveryId = active.deliveryId;
    final lastStoreId = (active.lastStoreId ?? '').trim();

    try {
      // Prefer store-scoped query (single where → no composite index)
      if (lastStoreId.isNotEmpty) {
        final s = await db
            .collection('tenants/$tenantId/stores/$lastStoreId/batches')
            .where('deliveryId', isEqualTo: deliveryId)
            .limit(1)
            .get();
        if (s.docs.isNotEmpty) return true;
      }

      // Fallback: collectionGroup + in-memory tenant filter
      final cg = await db
          .collectionGroup('batches')
          .where('deliveryId', isEqualTo: deliveryId)
          .limit(5)
          .get();

      return cg.docs.any(
        (d) => d.reference.path.contains('tenants/$tenantId/stores/'),
      );
    } catch (_) {
      return false;
    }
  });
});
