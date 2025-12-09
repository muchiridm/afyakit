// lib/hq/tenants/providers/tenant_providers.dart

import 'dart:async';

import 'package:afyakit/hq/domains/services/domain_tenant_resolver.dart';
import 'package:afyakit/hq/tenants/models/tenant_assets.dart';
import 'package:afyakit/hq/tenants/models/tenant_details.dart';
import 'package:afyakit/hq/tenants/models/tenant_features.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/hq/tenants/models/tenant_profile.dart';
import 'package:afyakit/hq/tenants/services/tenant_profile_loader.dart';

import 'package:afyakit/hq/tenants/dtos/team_member_dto.dart';
import 'package:afyakit/hq/users/all_users/all_user_model.dart';

const _defaultTenant = 'afyakit';

/// Base API origin used for tenant session repair.
/// Example: https://api.afyakit.app/api
const _apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://api.afyakit.app/api',
);

/// ─────────────────────────────────────────────────────────────
/// Loader singleton
/// ─────────────────────────────────────────────────────────────
final _profileLoaderProvider = Provider.autoDispose<TenantProfileLoader>((ref) {
  final db = FirebaseFirestore.instance;
  return TenantProfileLoader(db);
});

final tenantSlugProvider = Provider<String>((ref) {
  // 1) CLI / build-time override
  const fromDefine = String.fromEnvironment('TENANT', defaultValue: '');
  if (fromDefine.trim().isNotEmpty) {
    return fromDefine.trim().toLowerCase();
  }

  return resolveTenantSlug(defaultSlug: _defaultTenant);
});

/// ─────────────────────────────────────────────────────────────
/// Synchronous placeholder profile
/// Callers that need live data should use the stream/future providers.
/// ─────────────────────────────────────────────────────────────
final tenantProfileProvider = Provider<TenantProfile>((ref) {
  final slug = ref.watch(tenantSlugProvider);
  ref.watch(_profileLoaderProvider); // keep loader warm

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

final tenantProfileStreamProvider = StreamProvider.autoDispose<TenantProfile>((
  ref,
) {
  final slug = ref.watch(tenantSlugProvider);
  final loader = ref.watch(_profileLoaderProvider);
  return loader.stream(slug);
});

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

/// ─────────────────────────────────────────────────────────────
/// Internal: sync backend claims for the current tenant if needed.
/// This calls: POST $_apiBase/<tenant>/auth/session/sync-claims
/// which is whitelisted by SESSION_PATH_RE in the API.
/// ─────────────────────────────────────────────────────────────
Future<void> _ensureTenantClaims({
  required String tenantSlug,
  required fb.User fbUser,
}) async {
  try {
    // 1) Read current claims.
    final tokenResult = await fbUser.getIdTokenResult();
    final claims = tokenResult.claims ?? const <String, dynamic>{};

    final claimTenant = (claims['tenant'] ?? claims['tenantId'])?.toString();

    if (claimTenant == tenantSlug) {
      if (kDebugMode) {
        debugPrint(
          '✅ [guard] claims already match tenant=$tenantSlug (claimTenant=$claimTenant)',
        );
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '⚠️ [guard] tenant claim mismatch, pathTenant=$tenantSlug, '
        'claimTenant=$claimTenant → attempting sync-claims…',
      );
    }

    // 2) Call backend to repair claims.
    final dio = Dio(BaseOptions(baseUrl: _apiBase));

    final idToken = await fbUser.getIdToken(); // fresh enough for auth header
    final url = '/$tenantSlug/auth/session/sync-claims';

    await dio.post(
      url,
      options: Options(headers: {'Authorization': 'Bearer $idToken'}),
    );

    // 3) Force-refresh token so new claims are visible locally.
    await fbUser.getIdToken(true);

    if (kDebugMode) {
      final after = await fbUser.getIdTokenResult();
      final newTenant = (after.claims?['tenant'] ?? after.claims?['tenantId'])
          ?.toString();
      debugPrint(
        '✅ [guard] sync-claims OK for tenant=$tenantSlug (new claimTenant=$newTenant)',
      );
    }
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint(
        '❌ [guard] sync-claims failed for tenant=$tenantSlug: $e\n$st',
      );
    }
  }
}

/// ─────────────────────────────────────────────────────────────
/// Firestore + API tenant-guard
/// Ensures there is a signed-in Firebase user, a fresh token,
/// and (as best as we can) repaired tenant claims to match the
/// current tenant slug.
/// ─────────────────────────────────────────────────────────────
final firestoreTenantGuardProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final tenantSlug = ref.watch(tenantSlugProvider);

  // Keep alive briefly to avoid re-running for every tiny consumer.
  final link = ref.keepAlive();
  Timer? purge;
  ref.onCancel(() {
    purge = Timer(const Duration(seconds: 20), link.close);
  });
  ref.onResume(() => purge?.cancel());

  final fbUser = fb.FirebaseAuth.instance.currentUser;
  if (fbUser == null) {
    if (kDebugMode) {
      debugPrint('⚠️ [guard] no Firebase user for tenant=$tenantSlug');
    }
    return;
  }

  try {
    // Force a fresh token first.
    await fbUser.getIdToken(true);

    // Then ensure the backend session claims match this tenant.
    await _ensureTenantClaims(tenantSlug: tenantSlug, fbUser: fbUser);
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('❌ [guard] failed to refresh token for $tenantSlug: $e\n$st');
    }
  }
});
