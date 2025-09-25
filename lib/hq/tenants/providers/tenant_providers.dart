// lib/hq/core/tenants/providers/tenant_providers.dart

import 'dart:async';

import 'package:afyakit/core/auth_users/services/auth_session_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:afyakit/hq/tenants/models/tenant_config.dart';
import 'package:afyakit/hq/tenants/models/tenant_model.dart';
import 'package:afyakit/hq/tenants/models/team_member_dto.dart';
import 'package:afyakit/hq/tenants/providers/tenant_id_provider.dart';

import 'package:afyakit/hq/users/all_users/all_user_model.dart';

/// ─────────────────────────────────────────────────────────────
/// Tenant Config (override at bootstrap)
/// ─────────────────────────────────────────────────────────────

/// Override this in main() with the loaded TenantConfig.
final tenantConfigProvider = Provider<TenantConfig>((ref) {
  throw UnimplementedError('Override tenantConfigProvider in main()');
});

/// Smaller rebuild surface for common needs.
final tenantDisplayNameProvider = Provider<String>(
  (ref) => ref.watch(tenantConfigProvider).displayName,
);

/// ─────────────────────────────────────────────────────────────
/// Firestore: /tenants typed collection + helpers
/// ─────────────────────────────────────────────────────────────

final _tenantsRefProvider = Provider.autoDispose<CollectionReference<Tenant>>((
  ref,
) {
  final db = FirebaseFirestore.instance;
  return db
      .collection('tenants')
      .withConverter<Tenant>(
        fromFirestore: (snap, _) => _tenantFromDoc(snap),
        toFirestore: (_, __) => <String, dynamic>{}, // API handles writes
      );
});

Tenant _tenantFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
  final data = d.data() ?? <String, dynamic>{};
  final m = Map<String, dynamic>.from(data);

  m.putIfAbsent('slug', () => d.id);

  // Normalize createdAt for the model (ISO or leave if already DateTime)
  final created = m['createdAt'];
  if (created is Timestamp) {
    m['createdAt'] = created.toDate().toIso8601String();
  }

  m.putIfAbsent('displayName', () => m['name'] ?? d.id);
  m.putIfAbsent('status', () => 'active');
  m.putIfAbsent('primaryColor', () => '#1565C0');

  return Tenant.fromJson(m);
}

/// ─────────────────────────────────────────────────────────────
/// Tenants: lists & singletons
/// ─────────────────────────────────────────────────────────────

/// All tenants (live), newest first.
final tenantsStreamProvider = StreamProvider.autoDispose<List<Tenant>>((ref) {
  final col = ref.watch(_tenantsRefProvider);
  return col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.data()).toList());
});

/// Alphabetical by displayName (fallback slug).
final tenantsStreamProviderSorted = StreamProvider.autoDispose<List<Tenant>>((
  ref,
) {
  final base = ref.watch(tenantsStreamProvider.stream);
  return base.map((list) {
    final sorted = [...list]
      ..sort((a, b) {
        final ad = (a.displayName.isEmpty ? a.slug : a.displayName)
            .toLowerCase();
        final bd = (b.displayName.isEmpty ? b.slug : b.displayName)
            .toLowerCase();
        return ad.compareTo(bd);
      });
    return sorted;
  });
});

/// Single tenant (live) by slug.
final tenantStreamBySlugProvider = StreamProvider.autoDispose
    .family<Tenant, String>((ref, slug) {
      final col = ref.watch(_tenantsRefProvider);
      return col.doc(slug).snapshots().map((doc) {
        if (!doc.exists) throw StateError('tenant-not-found');
        return doc.data()!;
      });
    });

/// ─────────────────────────────────────────────────────────────
/// Tenant admins list (live) — Owner/Admin/Manager + active
/// ─────────────────────────────────────────────────────────────

const _adminRoles = <String>['owner', 'admin', 'manager'];

final tenantAdminsStreamProvider = StreamProvider.autoDispose
    .family<List<TenantMemberDTO>, String>((ref, slug) {
      final db = FirebaseFirestore.instance;

      final usersQ = db
          .collection('users')
          .where('tenantIds', arrayContains: slug);

      return usersQ.snapshots().asyncMap((usersSnap) async {
        if (usersSnap.docs.isEmpty) return <TenantMemberDTO>[];

        final futures = usersSnap.docs.map((uDoc) async {
          final uid = uDoc.id;
          final user = AllUser.fromJson(uid, uDoc.data());

          final mSnap = await db
              .collection('users')
              .doc(uid)
              .collection('memberships')
              .doc(slug)
              .get();

          final m = mSnap.data() ?? const <String, dynamic>{};
          final role = (m['role'] ?? 'staff').toString();
          final active = m['active'] == true;
          if (!active || !_adminRoles.contains(role)) return null;

          final ts = m['updatedAt'];
          final updatedAt = ts is Timestamp
              ? ts.toDate()
              : (ts is DateTime ? ts : null);

          return TenantMemberDTO(
            user: user,
            role: role,
            active: active,
            tenantId: slug,
            updatedAt: updatedAt,
          );
        }).toList();

        final items =
            (await Future.wait(futures)).whereType<TenantMemberDTO>().toList()
              ..sort((a, b) => a.user.emailLower.compareTo(b.user.emailLower));

        return items;
      });
    });

/// ─────────────────────────────────────────────────────────────
/// Firestore tenant-guard
/// Ensures non-superadmin token claims match selected tenant; refreshes if not.
/// ─────────────────────────────────────────────────────────────

final firestoreTenantGuardProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  final ops = await ref.watch(authSessionServiceProvider(tenantId).future);

  final link = ref.keepAlive();
  Timer? purge;
  ref.onCancel(() => purge = Timer(const Duration(seconds: 20), link.close));
  ref.onResume(() => purge?.cancel());

  Future<Map<String, dynamic>> readClaims() async {
    final claims = await ops.getClaims();
    if (kDebugMode) debugPrint('🔎 [guard] claims after read: $claims');
    return claims;
  }

  var claims = await readClaims();
  final initialTenant = (claims['tenantId'] ?? claims['tenant']) as String?;
  final isSuper = claims['superadmin'] == true;

  if (!isSuper && initialTenant != tenantId) {
    debugPrint(
      '🛠 [guard] claimTenant=$initialTenant ≠ selected=$tenantId → syncing…',
    );
    await ops.syncClaimsAndRefresh();
    claims = await readClaims();
  }

  final finalTenant = (claims['tenantId'] ?? claims['tenant']) as String?;
  if (!isSuper && finalTenant != tenantId) {
    throw StateError(
      'Tenant claim mismatch after sync (claim=$finalTenant, selected=$tenantId)',
    );
  }

  debugPrint('✅ [guard] claims ready for tenant=$tenantId (super=$isSuper)');
});
