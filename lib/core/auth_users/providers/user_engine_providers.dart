// lib/users/user_operations/providers/user_engine_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/api/api_client.dart';
import 'package:afyakit/api/api_routes.dart';

import 'package:afyakit/core/auth_users/services/auth_user_service.dart';
import 'package:afyakit/core/auth_users/controllers/auth_user_engine.dart';

/// Tenant-only AuthUserEngine (lean)
final authUserEngineProvider = FutureProvider.family<AuthUserEngine, String>((
  ref,
  tenantId,
) async {
  // Authenticated ApiClient (with token/interceptors)
  final client = await ref.read(apiClientProvider.future);

  // Tenant-scoped routes
  final routes = ApiRoutes(tenantId);

  // Tenant-scoped service
  final tenantSvc = AuthUserService(client: client, routes: routes);

  // Lean engine expects a single argument now
  return AuthUserEngine(tenantSvc);
});
