// lib/hq/tenants/providers/tenant_profile_stream_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/tenants/services/tenant_profile_service.dart';
import 'package:afyakit/hq/tenants/models/tenant_profile.dart';

final tenantProfilesStreamProvider =
    StreamProvider.autoDispose<List<TenantProfile>>((ref) async* {
      final svc = await ref.watch(tenantProfileServiceProvider.future);
      yield* svc.streamTenantProfiles();
    });
