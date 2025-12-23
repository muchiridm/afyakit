import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:afyakit/features/hq/tenants/services/tenant_admin_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream of all tenant profiles (for admin HQs)
final tenantProfilesStreamProvider =
    StreamProvider.autoDispose<List<TenantProfile>>((ref) async* {
      final svc = await ref.watch(tenantAdminServiceProvider.future);
      yield* svc.streamTenantProfiles();
    });
