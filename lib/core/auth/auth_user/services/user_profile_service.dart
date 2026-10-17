import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/config.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

final userProfileServiceProvider = FutureProvider.family<UserProfileService, String>((ref, tenantId) async {
  final cleanTenantId = tenantId.trim().toLowerCase();
  final appId = ref.watch(appIdProvider).trim().toLowerCase();
  final actorUid = fb.FirebaseAuth.instance.currentUser?.uid;
  final api = await AfyaKitClient.create(
    baseUrl: apiBaseUrl(cleanTenantId), appId: appId,
    getToken: () async {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != actorUid) throw StateError('Account changed. Reopen the profile.');
      return user.getIdToken();
    },
  );
  return UserProfileService(tenantId: cleanTenantId, appId: appId, client: api, routes: AfyaKitRoutes(cleanTenantId));
});

class UserProfileService {
  const UserProfileService({required this.tenantId, required this.appId, required this.client, required this.routes});
  final String tenantId;
  final String appId;
  final AfyaKitClient client;
  final AfyaKitRoutes routes;
  Dio get _dio => client.dio;
  Uri _scoped(Uri uri) {
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(appId)) throw StateError('Invalid app ID');
    return uri.replace(queryParameters: {...uri.queryParameters, 'appId': appId});
  }
  AuthUser _parseUser(Object? data) {
    if (data is! Map) throw StateError('Invalid account response');
    final user = AuthUser.fromMap(Map<String, dynamic>.from(data));
    if (user.tenantId != tenantId) throw StateError('Account tenant mismatch');
    return user.forApp(appId);
  }
  Future<AuthUser> getCurrentUser() async {
    final u = fb.FirebaseAuth.instance.currentUser;
    if (u == null) throw StateError('Sign in to load account');
    final res = await _dio.getUri(_scoped(routes.updateUser(u.uid)));
    final data = res.data is Map && (res.data as Map).containsKey('user') ? (res.data as Map)['user'] : res.data;
    final user = _parseUser(data);
    if (user.uid != u.uid) throw StateError('Account identity mismatch');
    final token = await u.getIdTokenResult();
    if (fb.FirebaseAuth.instance.currentUser?.uid != u.uid) throw StateError('Account changed.');
    return user.copyWith(isSuperAdmin: token.claims?['superadmin'] == true);
  }
  Future<List<AuthUser>> listTenantUsers() async {
    final res = await _dio.getUri(_scoped(routes.getAllUsers()));
    if (res.data is! List) throw StateError('Invalid account list response');
    return (res.data as List).map(_parseUser).toList(growable: false);
  }
  /// Backend PatchUserSchema accepts only `status`.
  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    if (fields.length != 1 || !fields.containsKey('status') ||
        !['active', 'disabled'].contains(fields['status'])) {
      throw ArgumentError('Only account status can be changed through AuthUser PATCH');
    }
    await _dio.patchUri(_scoped(routes.updateUser(uid)), data: fields);
  }
  Future<void> setAppStaffRoles(String uid, List<StaffRole> roles) async {
    final userUri = routes.updateUser(uid);
    final uri = userUri.replace(pathSegments: [...userUri.pathSegments.where((s) => s.isNotEmpty), 'apps', appId, 'staff-roles']);
    await _dio.putUri(_scoped(uri), data: {'staffRoles': roles.map((role) => role.wire).toSet().toList(growable: false)});
  }
}
