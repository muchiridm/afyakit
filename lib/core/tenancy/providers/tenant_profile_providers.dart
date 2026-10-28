// lib/core/tenancy/providers/tenant_profile_providers.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/capabilities/feature_set.dart';
import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/tenancy/services/tenant_profile_loader.dart';

final _tenantProfileLoaderProvider = Provider.autoDispose<TenantProfileLoader>((
  ref,
) {
  return TenantProfileLoader(FirebaseFirestore.instance);
});

/// Fetch-once tenant profile used during bootstrap.
///
/// TenantProfile is infrastructure-only:
/// - tenant id
/// - capability ceiling
/// - tenant status
///
/// Product identity and presentation belong to AppProfile.
final tenantProfileProvider = FutureProvider.autoDispose<TenantProfile>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);

  final loader = ref.watch(_tenantProfileLoaderProvider);

  try {
    return await loader.load(tenantId);
  } catch (_) {
    // Minimal bootstrap fallback.
    //
    // Product branding, names, contacts, payments and app feature exposure
    // are owned by AppProfile.
    return TenantProfile(id: tenantId, features: FeatureSet.fromMap(null));
  }
});
