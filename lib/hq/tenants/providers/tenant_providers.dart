// lib/hq/tenants/providers/tenant_providers.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:afyakit/hq/tenants/providers/tenant_slug_provider.dart';
import 'package:afyakit/hq/tenants/models/tenant_profile.dart';
import 'package:afyakit/hq/tenants/services/tenant_profile_loader.dart';

import 'package:afyakit/core/auth_users/services/auth_session_service.dart';

import 'package:afyakit/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/hq/tenants/dtos/team_member_dto.dart'; // just for the DTO shape

/// ─────────────────────────────────────────────────────────────
/// Loader singleton
/// ─────────────────────────────────────────────────────────────
final _profileLoaderProvider = Provider.autoDispose<TenantProfileLoader>((ref) {
  final db = FirebaseFirestore.instance;
  return TenantProfileLoader(db);
});

/// ─────────────────────────────────────────────────────────────
/// "tenantProfileProvider" → synchronous placeholder v2 profile
/// callers that need the real-time one should use the stream/future
/// ─────────────────────────────────────────────────────────────
final tenantProfileProvider = Provider<TenantProfile>((ref) {
  final slug = ref.watch(tenantSlugProvider);
  ref.watch(_profileLoaderProvider); // keep it alive

  return TenantProfile(
    id: slug,
    displayName: slug,
    primaryColorHex: '#1565C0',
    features: const TenantFeatures({}),
    assets: const TenantAssets(bucket: '', version: 0, logos: {}),
    details: const TenantDetails(
      tagline: null,
      website: null,
      email: null,
      whatsapp: null,
      currency: 'KES',
      locale: null,
      supportNote: null,
      social: {},
      hours: {},
      address: {},
      compliance: {},
      payments: {},
    ),
  );
});

/// Live stream version (v2)
final tenantProfileStreamProvider = StreamProvider.autoDispose<TenantProfile>((
  ref,
) {
  final slug = ref.watch(tenantSlugProvider);
  final loader = ref.watch(_profileLoaderProvider);
  return loader.stream(slug);
});

/// Smaller rebuild surface — display name
/// (FIX: this provider now reads the plain profile, not .maybeWhen)
final tenantDisplayNameProvider = Provider.autoDispose<String>((ref) {
  final slug = ref.watch(tenantSlugProvider);
  final asyncProfile = ref.watch(tenantProfileStreamProvider);

  return asyncProfile.maybeWhen(
    data: (p) {
      final name = p.displayName.trim();
      return name.isNotEmpty ? name : slug;
    },
    orElse: () => slug,
  );
});

/// ─────────────────────────────────────────────────────────────
/// /tenants collection → v2 TenantProfile list
/// ─────────────────────────────────────────────────────────────
final tenantsStreamProvider = StreamProvider.autoDispose<List<TenantProfile>>((
  ref,
) {
  final db = FirebaseFirestore.instance;
  return db
      .collection('tenants')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) {
        return snap.docs.map((d) {
          final data = d.data();
          return TenantProfile.fromFirestore(d.id, data);
        }).toList();
      });
});

final tenantsStreamProviderSorted =
    StreamProvider.autoDispose<List<TenantProfile>>((ref) {
      final base = ref.watch(tenantsStreamProvider.stream);
      return base.map((list) {
        final sorted = [...list]
          ..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );
        return sorted;
      });
    });

/// Single tenant (live) by slug
final tenantStreamBySlugProvider = StreamProvider.autoDispose
    .family<TenantProfile, String>((ref, slug) {
      final db = FirebaseFirestore.instance;
      return db.collection('tenants').doc(slug).snapshots().map((doc) {
        if (!doc.exists) throw StateError('tenant-not-found');
        return TenantProfile.fromFirestore(slug, doc.data() ?? const {});
      });
    });

/// ─────────────────────────────────────────────────────────────
/// Tenant admins list
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
/// Firestore tenant-guard → v2-only slug
/// ─────────────────────────────────────────────────────────────
final firestoreTenantGuardProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  // 👇 use the API-safe slug
  final tenantSlug = ref.watch(tenantSlugProvider);
  final ops = await ref.watch(authSessionServiceProvider(tenantSlug).future);

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

  if (!isSuper && initialTenant != tenantSlug) {
    debugPrint(
      '🛠 [guard] claimTenant=$initialTenant ≠ selected=$tenantSlug → syncing…',
    );
    await ops.syncClaimsAndRefresh();
    claims = await readClaims();
  }

  final finalTenant = (claims['tenantId'] ?? claims['tenant']) as String?;
  if (!isSuper && finalTenant != tenantSlug) {
    throw StateError(
      'Tenant claim mismatch after sync (claim=$finalTenant, selected=$tenantSlug)',
    );
  }

  debugPrint('✅ [guard] claims ready for tenant=$tenantSlug (super=$isSuper)');
});
