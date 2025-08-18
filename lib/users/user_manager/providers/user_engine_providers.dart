// lib/users/providers/engine_providers.dart
import 'package:afyakit/users/user_manager/services/user_manager_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/shared/providers/api_client_provider.dart';
import 'package:afyakit/users/user_manager/engines/user_manager_engine.dart';

/// ─────────────────────────────────────────────────────────
/// AuthUserEngine (tenant-scoped, async)
/// ─────────────────────────────────────────────────────────
final userManagerEngineProvider =
    FutureProvider.family<UserManagerEngine, String>((ref, tenantId) async {
      final client = await ref.read(apiClientProvider.future);
      final service = UserManagerService(
        client: client,
        routes: ApiRoutes(tenantId),
      );
      return UserManagerEngine(service);
    });
