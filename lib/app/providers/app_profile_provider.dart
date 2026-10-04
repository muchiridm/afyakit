// lib/app/providers/app_profile_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/app_identity.dart';
import 'package:afyakit/app/models/app_profile.dart';
import 'package:afyakit/app/services/app_profile_loader.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

final appProfileLoaderProvider = Provider<AppProfileLoader>((ref) {
  return AppProfileLoader(FirebaseFirestore.instance);
});

final appIdProvider = Provider<String>((ref) {
  return AppIdentity.appId;
});

final appProfileProvider = FutureProvider<AppProfile>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final appId = ref.watch(appIdProvider);

  final loader = ref.watch(appProfileLoaderProvider);

  return loader.load(tenantId: tenantId, appId: appId);
});
