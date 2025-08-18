// lib/users/providers/tenant_users_providers.dart
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/users/user_manager/models/auth_user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Internal helper to map query snapshots -> List<AuthUser>
List<AuthUser> _mapAuthUsers({
  required QuerySnapshot<Map<String, dynamic>> snapshot,
  required String tenantId,
}) {
  final out = <AuthUser>[];
  for (final doc in snapshot.docs) {
    if (!doc.exists) continue;
    final data = doc.data();
    if (data.isEmpty) continue;

    // Tolerate legacy docs missing tenantId
    final map = Map<String, dynamic>.from(data);
    map['tenantId'] ??= tenantId;

    try {
      out.add(AuthUser.fromMap(doc.id, map));
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Skipping ${doc.id}: $e');
    }
  }
  out.sort((a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()));
  return out;
}

/// 🚪 All users for a tenant (keep for screens that need everyone)
final tenantUsersStreamProvider = StreamProvider.autoDispose
    .family<List<AuthUser>, String>((ref, tenantId) {
      final query = db
          .collection('tenants')
          .doc(tenantId)
          .collection('auth_users')
          .orderBy('email');

      return query
          .snapshots(includeMetadataChanges: true)
          .map((snap) => _mapAuthUsers(snapshot: snap, tenantId: tenantId));
    });

/// 🛡️ Only **active admins/managers** — use this in Tenant Manager.
/// Reactive to role/active flips (local + server updates).
final tenantAdminsStreamProvider = StreamProvider.autoDispose
    .family<List<AuthUser>, String>((ref, tenantId) {
      final query = db
          .collection('tenants')
          .doc(tenantId)
          .collection('auth_users')
          .where('active', isEqualTo: true)
          .where('role', whereIn: ['admin', 'manager'])
          .orderBy('email');

      return query
          .snapshots(includeMetadataChanges: true)
          .map((snap) => _mapAuthUsers(snapshot: snap, tenantId: tenantId));
    });

/// 👤 Single auth user (useful for owner/admin row chips, etc.)
/// Call: ref.watch(tenantAuthUserStreamProvider({'tenantId': tid, 'uid': uid}))
final tenantAuthUserStreamProvider = StreamProvider.autoDispose
    .family<AuthUser?, Map<String, String>>((ref, args) {
      final tenantId = args['tenantId']!;
      final uid = args['uid']!;
      final docRef = db
          .collection('tenants')
          .doc(tenantId)
          .collection('auth_users')
          .doc(uid);

      return docRef.snapshots(includeMetadataChanges: true).map((doc) {
        if (!doc.exists) return null;
        final map = Map<String, dynamic>.from(doc.data()!);
        map['tenantId'] ??= tenantId;
        try {
          return AuthUser.fromMap(doc.id, map);
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Bad owner/admin doc ${doc.id}: $e');
          return null;
        }
      });
    });

/// 🏷️ Owner UID (from tenant doc) — reactive to owner transfer
final tenantOwnerUidStreamProvider = StreamProvider.autoDispose
    .family<String?, String>((ref, tenantId) {
      return db
          .collection('tenants')
          .doc(tenantId)
          .snapshots(includeMetadataChanges: true)
          .map((d) => (d.data()?['ownerUid'] as String?));
    });

/// 👑 Owner as AuthUser (streams null if none/unknown)
final tenantOwnerStreamProvider = StreamProvider.autoDispose
    .family<AuthUser?, String>((ref, tenantId) {
      final ownerUidAsync = ref.watch(tenantOwnerUidStreamProvider(tenantId));
      return ownerUidAsync.when(
        data: (uid) {
          if (uid == null || uid.isEmpty) {
            return const Stream<AuthUser?>.empty();
          }
          return ref.watch(
            tenantAuthUserStreamProvider({
              'tenantId': tenantId,
              'uid': uid,
            }).stream,
          );
        },
        loading: () => const Stream.empty(),
        error: (_, __) => const Stream.empty(),
      );
    });
