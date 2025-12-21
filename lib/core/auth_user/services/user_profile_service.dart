// lib/core/auth_user/services/user_profile_service.dart

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/config.dart';
import 'package:afyakit/core/api/afyakit/routes.dart';

import 'package:afyakit/core/auth_user/models/auth_user_model.dart';

final userProfileServiceProvider =
    FutureProvider.family<UserProfileService, String>((ref, tenantId) async {
      final api = await AfyaKitClient.create(
        baseUrl: apiBaseUrl(tenantId),
        getToken: () async =>
            await fb.FirebaseAuth.instance.currentUser?.getIdToken(),
      );

      return UserProfileService(
        tenantId: tenantId,
        client: api,
        routes: AfyaKitRoutes(tenantId),
      );
    });

class UserProfileService {
  UserProfileService({
    required this.tenantId,
    required this.client,
    required this.routes,
  });

  final String tenantId;
  final AfyaKitClient client;
  final AfyaKitRoutes routes;

  Dio get _dio => client.dio;

  Future<AuthUser> getCurrentUser() async {
    final res = await _dio.getUri(routes.getCurrentUser());
    final json = jsonDecode(jsonEncode(res.data)) as Map<String, dynamic>;
    return AuthUser.fromMap(json);
  }

  /// Admin/HQ: list all tenant users (memberships)
  Future<List<AuthUser>> listTenantUsers() async {
    final res = await _dio.getUri(routes.getAllUsers());
    final data = res.data;
    if (data is! List) return const [];

    return data
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .map(AuthUser.fromMap)
        .toList();
  }

  /// Patch user fields (tenant-scoped profile/membership)
  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    await _dio.patchUri(routes.updateUser(uid), data: fields);
  }
}
