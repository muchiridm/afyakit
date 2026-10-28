// lib/core/auth/auth_user/services/user_profile_service.dart

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/providers/app_profile_provider.dart';
import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/config.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

final userProfileServiceProvider =
    FutureProvider.family<UserProfileService, String>((ref, tenantId) async {
      final cleanTenantId = tenantId.trim().toLowerCase();

      final appId = ref.watch(appIdProvider).trim().toLowerCase();

      final actorUid = fb.FirebaseAuth.instance.currentUser?.uid;

      final api = await AfyaKitClient.create(
        baseUrl: apiBaseUrl(cleanTenantId),
        appId: appId,
        getToken: () async {
          final user = fb.FirebaseAuth.instance.currentUser;

          if (user == null || user.uid != actorUid) {
            throw StateError('Account changed. Reopen the profile.');
          }

          return user.getIdToken();
        },
      );

      return UserProfileService(
        tenantId: cleanTenantId,
        appId: appId,
        client: api,
        routes: AfyaKitRoutes(cleanTenantId),
      );
    });

class UserProfileService {
  UserProfileService({
    required this.tenantId,
    required this.appId,
    required this.client,
    required this.routes,
  });

  final String tenantId;
  final String appId;
  final AfyaKitClient client;
  final AfyaKitRoutes routes;

  Dio get _dio => client.dio;

  Uri _scoped(Uri uri) {
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(appId)) {
      throw StateError('Invalid app ID');
    }

    return uri.replace(
      queryParameters: {...uri.queryParameters, 'appId': appId},
    );
  }

  AuthUser _parseUser(Object? data) {
    if (data is! Map) {
      throw StateError('Invalid account response');
    }

    final user = AuthUser.fromMap(Map<String, dynamic>.from(data));

    if (user.tenantId != tenantId) {
      throw StateError('Account tenant mismatch');
    }

    return user.forApp(appId);
  }

  Future<AuthUser> getCurrentUser() async {
    final firebaseUser = fb.FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      throw StateError('Sign in to load your account');
    }

    // GET and PATCH share /users/:uid.
    // Read the full canonical tenant account.
    final res = await _dio.getUri(_scoped(routes.updateUser(firebaseUser.uid)));

    final user = _parseUser(res.data);

    if (user.uid != firebaseUser.uid) {
      throw StateError('Account identity mismatch');
    }

    final token = await firebaseUser.getIdTokenResult();

    if (fb.FirebaseAuth.instance.currentUser?.uid != firebaseUser.uid) {
      throw StateError('Account changed. Reopen the profile.');
    }

    return user.copyWith(isSuperAdmin: token.claims?['superadmin'] == true);
  }

  /// Tenant-wide listing is restricted by the backend to platform admins.
  Future<List<AuthUser>> listTenantUsers() async {
    final res = await _dio.getUri(_scoped(routes.getAllUsers()));
    final data = res.data;

    if (data is! List) {
      throw StateError('Invalid account list response');
    }

    return data.map(_parseUser).toList(growable: false);
  }

  /// General profile fields. Staff roles use the separate app endpoint.
  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    if (fields.containsKey('staffRoles') ||
        fields.containsKey('staffRolesByApp')) {
      throw ArgumentError('Use setAppStaffRoles for staff role changes');
    }

    await _dio.patchUri(_scoped(routes.updateUser(uid)), data: fields);
  }

  /// Replace roles for this tenant/app only. An empty list revokes them.
  Future<void> setAppStaffRoles(String uid, List<StaffRole> roles) async {
    final userUri = routes.updateUser(uid);

    final uri = userUri.replace(
      pathSegments: [
        ...userUri.pathSegments.where((segment) => segment.isNotEmpty),
        'apps',
        appId,
        'staff-roles',
      ],
    );

    await _dio.putUri(
      _scoped(uri),
      data: {
        'staffRoles': roles
            .map((role) => role.wire)
            .toSet()
            .toList(growable: false),
      },
    );
  }
}
