// lib/users/user_operations/providers/user_operations_engine_providers.dart
import 'package:afyakit/core/auth_users/services/user_operations_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/auth_users/user_operations/engines/login_engine.dart';
import 'package:afyakit/core/auth_users/user_operations/engines/session_engine.dart';

final loginEngineProvider = FutureProvider.family
    .autoDispose<LoginEngine, String>((ref, tenantId) async {
      final ops = await ref.read(
        userOperationsServiceProvider(tenantId).future,
      );
      return LoginEngine(ops: ops);
    });

final sessionEngineProvider = FutureProvider.family
    .autoDispose<SessionEngine, String>((ref, tenantId) async {
      final ops = await ref.read(
        userOperationsServiceProvider(tenantId).future,
      );
      return SessionEngine(ops: ops, tenantId: tenantId);
    });
