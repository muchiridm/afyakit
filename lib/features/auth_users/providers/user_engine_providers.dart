// lib/users/providers/engine_providers.dart
import 'package:afyakit/features/auth_users/user_manager/services/global_users_service.dart';
import 'package:afyakit/features/auth_users/user_manager/services/user_manager_service.dart';
import 'package:afyakit/features/api/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/api/api_routes.dart';
import 'package:afyakit/features/auth_users/user_manager/engines/user_manager_engine.dart';

/// ─────────────────────────────────────────────────────────
/// AuthUserEngine (tenant-scoped, async)
/// ─────────────────────────────────────────────────────────
// lib/users/user_manager/providers/user_engine_providers.dart

final userManagerEngineProvider = FutureProvider.family<UserManagerEngine, String>(
  (ref, tenantId) async {
    // Same authenticated ApiClient you already use (token + interceptors)
    final client = await ref.read(apiClientProvider.future);

    // Routes instance you already pass to tenant-scoped service
    // (HQ endpoints like hqDeleteUser(...) are exposed off the same ApiRoutes).
    final routes = ApiRoutes(tenantId);

    // Tenant-scoped service (CRUD inside the current tenant)
    final tenantSvc = UserManagerService(client: client, routes: routes);

    // HQ (cross-tenant) service — REQUIRED for “Remove admin” on Tenant Manager
    final hqSvc = GlobalUsersService(
      client: client,
      routes: routes, // ok to reuse; HQ methods take targetTenantId explicitly
    );

    // Pass BOTH services to enable HQ features
    return UserManagerEngine(tenantSvc, hqSvc);
  },
);
