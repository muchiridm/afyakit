// lib/core/tenancy/providers/tenant_profile_providers.dart

import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_session_guard_provider.dart';
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

/// Fetch-once (with cache fallback), same as v1 but v2 model.
final tenantProfileProvider = FutureProvider.autoDispose<TenantProfile>((
  ref,
) async {
  await ref.watch(
    tenantSessionGuardProvider.future,
  ); // 👈 ensures claims are sane
  final slug = ref.watch(tenantSlugProvider);
  final loader = ref.watch(_tenantProfileLoaderProvider);
  return loader.load(slug);
});

/// Live stream version (admin dashboards, HQ, etc.)
final tenantProfileStreamProvider = StreamProvider.autoDispose<TenantProfile>((
  ref,
) {
  final slug = ref.watch(tenantSlugProvider);
  final loader = ref.watch(_tenantProfileLoaderProvider);
  return loader.stream(slug);
});

/// Smaller rebuild surface — just the display name
final tenantProfileDisplayNameProvider = Provider.autoDispose<String>((ref) {
  final asyncProfile = ref.watch(tenantProfileProvider);
  return asyncProfile.maybeWhen(data: (p) => p.displayName, orElse: () => '');
});

/// Smaller rebuild surface — primary color
final tenantProfilePrimaryColorProvider = Provider.autoDispose<Color?>((ref) {
  final asyncProfile = ref.watch(tenantProfileProvider);
  return asyncProfile.maybeWhen(
    data: (p) => p.primaryColor,
    orElse: () => null,
  );
});

/// Smaller rebuild surface — logo url (you had this logic in assets)
final tenantProfileLogoUrlProvider = Provider.autoDispose<String?>((ref) {
  final asyncProfile = ref.watch(tenantProfileProvider);
  return asyncProfile.maybeWhen(data: (p) => p.logoUrl(), orElse: () => null);
});

/// Display name with slug fallback (useful for headers).
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
