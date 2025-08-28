// lib/features/records/delivery_sessions/providers/delivery_banner_provider.dart
import 'package:afyakit/core/records/delivery_sessions/providers/active_delivery_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/hq/core/tenants/providers/tenant_id_provider.dart';

/// Show banner iff the signed-in user has an *open* temp session
/// that already has at least one linked batch in this tenant.
final deliveryBannerVisibleProvider = StreamProvider.autoDispose<bool>((
  ref,
) async* {
  final tenantId = ref.watch(tenantIdProvider);

  // Listen to changes in the active (open, not finalized) temp session
  final activeStream = ref.watch(activeDeliverySessionProvider.stream);

  await for (final active in activeStream) {
    if (tenantId.isEmpty || active == null) {
      yield false;
      continue;
    }

    final deliveryId = active.deliveryId;
    final lastStoreId = (active.lastStoreId ?? '').trim();

    bool show = false;

    try {
      // Prefer store-scoped query (single where → no composite index)
      if (lastStoreId.isNotEmpty) {
        final s = await db
            .collection('tenants/$tenantId/stores/$lastStoreId/batches')
            .where('deliveryId', isEqualTo: deliveryId)
            .limit(1)
            .get();

        if (s.docs.isNotEmpty) {
          show = true;
        }
      }

      // Fallback: collectionGroup filtered by deliveryId, then tenant check in-memory
      if (!show) {
        final cg = await db
            .collectionGroup('batches')
            .where('deliveryId', isEqualTo: deliveryId) // single-field filter
            .limit(5)
            .get();

        show = cg.docs.any(
          (d) => d.reference.path.contains('tenants/$tenantId/stores/'),
        );
      }
    } catch (_) {
      show = false;
    }

    yield show;
  }
});
