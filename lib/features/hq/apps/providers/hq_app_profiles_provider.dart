// lib/features/hq/apps/providers/hq_app_profiles_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/models/app_profile.dart';
import 'package:afyakit/app/models/zoho_app_config.dart';
import 'package:afyakit/features/hq/apps/services/app_profile_service.dart';

// ═════════════════════════════════════════════
// App profiles
// ═════════════════════════════════════════════

final hqAppProfilesProvider = FutureProvider.autoDispose
    .family<List<AppProfile>, String>((ref, tenantId) async {
      final cleanTenantId = _cleanId(tenantId);

      if (cleanTenantId.isEmpty) {
        return const <AppProfile>[];
      }

      final service = await ref.watch(appProfileServiceProvider.future);

      return service.fetchAppProfiles(tenantId: cleanTenantId);
    });

final hqAppProfileProvider = FutureProvider.autoDispose
    .family<AppProfile, ({String tenantId, String appId})>((ref, input) async {
      final tenantId = _cleanId(input.tenantId);
      final appId = _cleanId(input.appId);

      if (tenantId.isEmpty) {
        throw ArgumentError('tenantId cannot be empty');
      }

      if (appId.isEmpty) {
        throw ArgumentError('appId cannot be empty');
      }

      final service = await ref.watch(appProfileServiceProvider.future);

      return service.getAppProfile(tenantId: tenantId, appId: appId);
    });

// ═════════════════════════════════════════════
// App Zoho Books configuration
//
// /api/hq/tenants/:tenantId/apps/:appId/zoho
// ═════════════════════════════════════════════

typedef HqAppScope = ({String tenantId, String appId});

final hqAppZohoProvider = FutureProvider.autoDispose
    .family<ZohoAppConfig, HqAppScope>((ref, input) async {
      final tenantId = _cleanId(input.tenantId);
      final appId = _cleanId(input.appId);

      if (tenantId.isEmpty) {
        throw ArgumentError('tenantId cannot be empty');
      }

      if (appId.isEmpty) {
        throw ArgumentError('appId cannot be empty');
      }

      final service = await ref.watch(appProfileServiceProvider.future);

      return service.getZohoConfig(tenantId: tenantId, appId: appId);
    });

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

String _cleanId(String value) {
  return value.trim().toLowerCase();
}
