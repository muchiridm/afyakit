import 'package:afyakit/core/auth_users/providers/auth_session/current_user_providers.dart';
import 'package:afyakit/core/records/deliveries/models/active_temp_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/hq/tenants/providers/tenant_slug_provider.dart';

/// Emits the **latest open** temp session for the signed-in user, or null.
/// Reactive to both tenantId and current user changes.
final activeDeliverySessionProvider =
    StreamProvider.autoDispose<ActiveTempSession?>((ref) {
      final tenantId = ref.watch(tenantSlugProvider);
      final userAsync = ref.watch(currentUserProvider); // AsyncValue<AuthUser?>

      return userAsync.when(
        data: (user) {
          final email = (user?.email ?? '').trim().toLowerCase();
          if (tenantId.isEmpty || email.isEmpty) {
            // Emit a single null so downstream UI won’t get “stuck”.
            return Stream<ActiveTempSession?>.value(null);
          }

          final q = db
              .collection('tenants')
              .doc(tenantId)
              .collection('delivery_records_temp')
              .where('enteredByEmail', isEqualTo: email)
              .where('isFinalized', isEqualTo: false)
              .limit(10); // scan a few; no composite index required

          return q.snapshots().map((snap) {
            if (snap.docs.isEmpty) return null;

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

            if (best == null) return null;
            final id = (best['deliveryId'] as String?)?.trim() ?? '';
            if (id.isEmpty) return null;

            return ActiveTempSession(
              deliveryId: id,
              enteredByEmail:
                  (best['enteredByEmail'] as String?)?.trim() ?? email,
              enteredByName: (best['enteredByName'] as String?)?.trim(),
              lastStoreId: (best['lastStoreId'] as String?)?.trim(),
              lastSource: (best['lastSource'] as String?)?.trim(),
            );
          });
        },
        // While user is loading, don’t emit anything to avoid flicker.
        loading: () => const Stream<ActiveTempSession?>.empty(),
        // On error, present as “no active session” instead of breaking the tree.
        error: (_, __) => Stream<ActiveTempSession?>.value(null),
      );
    });
