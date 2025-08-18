// lib/shared/providers/api_route_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/hq/tenants/providers/tenant_id_provider.dart';

final apiRouteProvider = Provider<ApiRoutes>((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  return ApiRoutes(tenantId);
});
