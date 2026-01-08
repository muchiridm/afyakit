// lib/core/tenancy/providers/tenant_profile_providers.dart

import 'package:afyakit/core/tenancy/models/tenant_assets.dart';
import 'package:afyakit/core/tenancy/models/tenant_details.dart';
import 'package:afyakit/core/tenancy/models/tenant_features.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:afyakit/core/tenancy/services/tenant_profile_loader.dart';

/// Loader singleton (you can also provide FirebaseFirestore via DI)
final _tenantProfileLoaderProvider = Provider.autoDispose<TenantProfileLoader>((
  ref,
) {
  final db = FirebaseFirestore.instance;
  return TenantProfileLoader(db);
});

/// ✅ Fetch-once profile (public bootstrap).
/// IMPORTANT:
/// - Must NOT depend on auth session.
/// - Must NOT be bricked by deleted users / missing memberships.
final tenantProfileProvider = FutureProvider.autoDispose<TenantProfile>((
  ref,
) async {
  final slug = ref.watch(tenantSlugProvider);
  final loader = ref.watch(_tenantProfileLoaderProvider);

  try {
    return await loader.load(slug);
  } catch (_) {
    // ✅ Hard failsafe: let UI render login/guest even if profile load fails.
    return TenantProfile(
      id: slug,
      displayName: slug,
      primaryColorHex: '#2196F3',
      features: TenantFeatures.fromMap(null),
      assets: TenantAssets.fromMap(null),
      details: TenantDetails.fromMap(const {}),
    );
  }
});

/// Live stream version (admin dashboards, HQ, etc.)
final tenantProfileStreamProvider = StreamProvider.autoDispose<TenantProfile>((
  ref,
) {
  final slug = ref.watch(tenantSlugProvider);
  final loader = ref.watch(_tenantProfileLoaderProvider);
  return loader.stream(slug);
});

final tenantProfileDisplayNameProvider = Provider.autoDispose<String>((ref) {
  final asyncProfile = ref.watch(tenantProfileProvider);
  return asyncProfile.maybeWhen(data: (p) => p.displayName, orElse: () => '');
});

final tenantProfilePrimaryColorProvider = Provider.autoDispose<Color?>((ref) {
  final asyncProfile = ref.watch(tenantProfileProvider);
  return asyncProfile.maybeWhen(
    data: (p) => p.primaryColor,
    orElse: () => null,
  );
});

final tenantProfileLogoUrlProvider = Provider.autoDispose<String?>((ref) {
  final asyncProfile = ref.watch(tenantProfileProvider);
  return asyncProfile.maybeWhen(data: (p) => p.logoUrl(), orElse: () => null);
});

final tenantDisplayNameProvider = Provider.autoDispose<String>((ref) {
  final slug = ref.watch(tenantSlugProvider);
  final asyncProfile = ref.watch(tenantProfileProvider);

  return asyncProfile.maybeWhen(
    data: (p) {
      final name = p.displayName.trim();
      return name.isNotEmpty ? name : slug;
    },
    orElse: () => slug,
  );
});
