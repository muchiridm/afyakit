// lib/hq/global_users/global_users_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart'; // if you expose `firestore`

import 'package:afyakit/features/auth_users/models/global_user_model.dart';

final globalUsersSearchProvider = StateProvider.autoDispose<String>((_) => '');
final globalUsersLimitProvider = StateProvider.autoDispose<int>((_) => 50);

/// Live stream from top-level `users` (not tenant-scoped).
final globalUsersStreamProvider = StreamProvider.autoDispose<List<GlobalUser>>((
  ref,
) {
  final search = ref.watch(globalUsersSearchProvider).trim().toLowerCase();
  final limitRaw = ref.watch(globalUsersLimitProvider);
  final safeLimit = limitRaw > 0 ? limitRaw : 50;

  // Prefer your FireFlex instance if you export one; otherwise fallback.
  final db = /* firestore ?? */ FirebaseFirestore.instance;

  Query<Map<String, dynamic>> q = db.collection('users');

  if (search.isNotEmpty) {
    // prefix search on normalized field (must be stored lowercase)
    q = q.orderBy('emailLower').startAt([search]).endAt(['$search\uf8ff']);
  } else {
    q = q.orderBy('createdAt', descending: true);
  }

  q = q.limit(safeLimit);

  return q.snapshots().map(
    (snap) =>
        snap.docs.map((d) => GlobalUser.fromJson(d.id, d.data())).toList(),
  );
});

/// Live map of memberships for a user: { tenantId: {role, active} }
final userMembershipsStreamProvider = StreamProvider.autoDispose
    .family<Map<String, Map<String, Object?>>, String>((ref, uid) {
      final db = /* firestore ?? */ FirebaseFirestore.instance;
      final col = db.collection('users').doc(uid).collection('memberships');

      return col.snapshots().map((qs) {
        final map = <String, Map<String, Object?>>{};
        for (final d in qs.docs) {
          final m = d.data();
          map[d.id] = {
            'role': (m['role'] ?? 'staff').toString(),
            'active': m['active'] == true,
          };
        }
        return map;
      });
    });
