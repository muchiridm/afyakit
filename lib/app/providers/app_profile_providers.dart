// lib/app/providers/app_profile_providers.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/app_identity.dart';
import 'package:afyakit/app/models/app_profile.dart';
import 'package:afyakit/app/services/app_profile_loader.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

final appProfileLoaderProvider = Provider.autoDispose<AppProfileLoader>((ref) {
  return AppProfileLoader(FirebaseFirestore.instance);
});

final appIdProvider = Provider.autoDispose<String>((ref) {
  return AppIdentity.appId;
});

/// Profile for the currently running application.
///
/// AppProfile owns product-level configuration, including:
/// - application identity
/// - branding
/// - presentation
/// - app-specific feature exposure
///
/// TenantProfile defines the tenant-wide capability ceiling.
/// Runtime product UI should normally use AppProfile rather than
/// TenantProfile when deciding which features to expose.
final appProfileProvider = FutureProvider.autoDispose<AppProfile>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final appId = ref.watch(appIdProvider);

  final loader = ref.watch(appProfileLoaderProvider);

  return loader.load(tenantId: tenantId, appId: appId);
});
