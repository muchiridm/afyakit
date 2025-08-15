// lib/users/providers/engine_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/shared/providers/api_client_provider.dart';
import 'package:afyakit/shared/providers/api_route_provider.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:afyakit/users/services/auth_user_service.dart';
import 'package:afyakit/users/services/firebase_auth_service.dart';
import 'package:afyakit/users/services/user_profile_service.dart';
import 'package:afyakit/users/services/user_session_service.dart';
import 'package:afyakit/users/engines/session_engine.dart';
import 'package:afyakit/users/engines/login_engine.dart';
import 'package:afyakit/users/engines/auth_user_engine.dart';
import 'package:afyakit/users/engines/profile_engine.dart';

/// ─────────────────────────────────────────────────────────
/// SessionEngine (tenant-scoped, async)
/// ─────────────────────────────────────────────────────────
final sessionEngineProvider = FutureProvider.family<SessionEngine, String>((
  ref,
  tenantId,
) async {
  final auth = ref.read(firebaseAuthServiceProvider);
  final client = await ref.read(apiClientProvider.future);
  final token = ref.read(tokenProvider);
  final routes = ApiRoutes(tenantId);

  final session = UserSessionService(
    client: client,
    routes: routes,
    tokenProvider: token,
  );

  return SessionEngine(auth: auth, session: session);
});

/// ─────────────────────────────────────────────────────────
/// LoginEngine (uses global routes, async client)
/// ─────────────────────────────────────────────────────────
final loginEngineProvider = FutureProvider<LoginEngine>((ref) async {
  final auth = ref.read(firebaseAuthServiceProvider);
  final routes = ref.read(apiRouteProvider);
  final token = ref.read(tokenProvider);
  final client = await ref.read(apiClientProvider.future);

  final session = UserSessionService(
    client: client,
    routes: routes,
    tokenProvider: token,
  );

  return LoginEngine(auth: auth, session: session);
});

/// ─────────────────────────────────────────────────────────
/// AuthUserEngine (tenant-scoped, async)
/// ─────────────────────────────────────────────────────────
final authUserEngineProvider = FutureProvider.family<AuthUserEngine, String>((
  ref,
  tenantId,
) async {
  final client = await ref.read(apiClientProvider.future);
  final service = AuthUserService(client: client, routes: ApiRoutes(tenantId));
  return AuthUserEngine(service);
});

/// If you prefer reading tenantId from provider instead of passing it in:
/// final authUserEngineProvider = FutureProvider<AuthUserEngine>((ref) async {
///   final tenantId = ref.read(tenantIdProvider);
///   final client   = await ref.read(apiClientProvider.future);
///   return AuthUserEngine(AuthUserService(client: client, routes: ApiRoutes(tenantId)));
/// });

/// ─────────────────────────────────────────────────────────
/// ProfileEngine (tenant-scoped, async)
/// ─────────────────────────────────────────────────────────
final profileEngineProvider = FutureProvider.family<ProfileEngine, String>((
  ref,
  tenantId,
) async {
  final client = await ref.read(apiClientProvider.future);

  return ProfileEngine(
    profiles: UserProfileService(client: client, routes: ApiRoutes(tenantId)),
    authUsers: AuthUserService(client: client, routes: ApiRoutes(tenantId)),
  );
});
