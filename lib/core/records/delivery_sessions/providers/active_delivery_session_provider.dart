// lib/features/records/delivery_sessions/providers/active_delivery_session_provider.dart
import 'package:afyakit/core/auth_users/providers/auth_session/current_user_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/hq/core/tenants/providers/tenant_id_provider.dart';

// Minimal TempSession (matches your model/fields)
class ActiveTempSession {
  final String deliveryId;
  final String enteredByEmail;
  final String? enteredByName;
  final String? lastStoreId;
  final String? lastSource;
  ActiveTempSession({
    required this.deliveryId,
    required this.enteredByEmail,
    this.enteredByName,
    this.lastStoreId,
    this.lastSource,
  });
}

/// Emits the **latest open** temp session for the signed-in user, or null.
final activeDeliverySessionProvider =
    StreamProvider.autoDispose<ActiveTempSession?>((ref) async* {
      final tenantId = ref.watch(tenantIdProvider);
      final user = await ref.watch(currentUserFutureProvider.future);
      final email = (user?.email ?? '').trim().toLowerCase();

      if (tenantId.isEmpty || email.isEmpty) {
        yield null;
        return;
      }

      final q = db
          .collection('tenants')
          .doc(tenantId)
          .collection('delivery_records_temp')
          .where('enteredByEmail', isEqualTo: email)
          .where('isFinalized', isEqualTo: false)
          .limit(10); // scan a few

      await for (final snap in q.snapshots()) {
        if (snap.docs.isEmpty) {
          yield null;
          continue;
        }

        int bestTs = -1;
        Map<String, dynamic>? best;
        for (final d in snap.docs) {
          final m = d.data();
          final ts = (m['updatedAt'] is Timestamp)
              ? (m['updatedAt'] as Timestamp).millisecondsSinceEpoch
              : 0;
          if (ts > bestTs) {
            bestTs = ts;
            best = m;
          }
        }

        if (best == null) {
          yield null;
          continue;
        }
        final id = (best['deliveryId'] as String?)?.trim() ?? '';
        if (id.isEmpty) {
          yield null;
          continue;
        }

        yield ActiveTempSession(
          deliveryId: id,
          enteredByEmail: (best['enteredByEmail'] as String?)?.trim() ?? email,
          enteredByName: (best['enteredByName'] as String?)?.trim(),
          lastStoreId: (best['lastStoreId'] as String?)?.trim(),
          lastSource: (best['lastSource'] as String?)?.trim(),
        );
      }
    });
