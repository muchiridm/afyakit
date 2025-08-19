// lib/users/user_manager/providers/super_admin_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart'; // exports FirebaseFirestore
import 'package:afyakit/users/user_manager/models/super_admim_model.dart';

/// Base Firestore query (global, not tenant-scoped)
final _superAdminsQueryProvider = Provider.autoDispose((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('claims.superadmin', isEqualTo: true);
});

/// One-shot fetch
final superAdminListProvider = FutureProvider.autoDispose<List<SuperAdmin>>((
  ref,
) async {
  final q = ref.read(_superAdminsQueryProvider);
  final snap = await q.get();
  return snap.docs
      .map(
        (d) => SuperAdmin.fromJson(<String, dynamic>{'uid': d.id, ...d.data()}),
      )
      .toList();
});

/// Live stream (unsorted)
final superAdminStreamProvider = StreamProvider.autoDispose<List<SuperAdmin>>((
  ref,
) {
  final q = ref.watch(_superAdminsQueryProvider);
  return q.snapshots().map((snap) {
    return snap.docs
        .map(
          (d) =>
              SuperAdmin.fromJson(<String, dynamic>{'uid': d.id, ...d.data()}),
        )
        .toList();
  });
});

/// Live stream sorted by email → displayName → uid (client-side)
final superAdminStreamSortedProvider =
    StreamProvider.autoDispose<List<SuperAdmin>>((ref) {
      final base = ref.watch(superAdminStreamProvider.stream);
      return base.map((list) {
        final sorted = [...list]
          ..sort((a, b) {
            String key(SuperAdmin s) =>
                (s.email?.toLowerCase().trim().isNotEmpty == true
                ? s.email!.toLowerCase().trim()
                : (s.displayName?.toLowerCase().trim().isNotEmpty == true
                      ? s.displayName!.toLowerCase().trim()
                      : s.uid.toLowerCase()))
            // ensure stable sorting for ties
            ;
            return key(a).compareTo(key(b));
          });
        return sorted;
      });
    });

/// Optional: count (useful for badges)
final superAdminCountProvider = Provider.autoDispose<int>((ref) {
  final async = ref.watch(superAdminStreamProvider);
  return async.maybeWhen(data: (l) => l.length, orElse: () => 0);
});
