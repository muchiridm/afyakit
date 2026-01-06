// lib/core/tenancy/providers/tenant_providers.dart

import 'dart:async';

import 'package:afyakit/core/domains/services/domain_tenant_resolver.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:afyakit/features/hq/tenants/dtos/team_member_dto.dart';
import 'package:afyakit/features/hq/users/all_users/all_user_model.dart';

const _defaultTenant = 'afyakit';

final tenantSlugProvider = Provider<String>((ref) {
  // 1) CLI / build-time override
  const fromDefine = String.fromEnvironment('TENANT', defaultValue: '');
  if (fromDefine.trim().isNotEmpty) {
    return fromDefine.trim().toLowerCase();
  }

  // 2) Domain resolver (web) / fallback
  return resolveTenantSlug(defaultSlug: _defaultTenant);
});

/// ─────────────────────────────────────────────────────────────
/// /tenants collection streams
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

/// Same list but sorted alphabetically by display name
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
