// lib/features/hq/apps/providers/hq_app_profiles_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/models/app_profile.dart';
import 'package:afyakit/features/hq/apps/services/app_profile_service.dart';

final hqAppProfilesProvider = FutureProvider.autoDispose
    .family<List<AppProfile>, String>((ref, tenantId) async {
      final cleanTenantId = tenantId.trim().toLowerCase();

      if (cleanTenantId.isEmpty) {
        return const <AppProfile>[];
      }

      final service = await ref.watch(appProfileServiceProvider.future);

      return service.fetchAppProfiles(tenantId: cleanTenantId);
    });

final hqAppProfileProvider = FutureProvider.autoDispose
    .family<AppProfile, ({String tenantId, String appId})>((ref, input) async {
      final service = await ref.watch(appProfileServiceProvider.future);

      return service.getAppProfile(
        tenantId: input.tenantId.trim().toLowerCase(),
        appId: input.appId.trim().toLowerCase(),
      );
    });
