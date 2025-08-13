import 'package:afyakit/shared/api/api_client.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/users/models/user_profile.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class UserProfileService {
  final ApiClient client;
  final ApiRoutes routes;

  UserProfileService({required this.client, required this.routes});

  // ─────────────────────────────────────────────
  // 🔍 Fetch user profile by UID
  // ─────────────────────────────────────────────
  Future<UserProfile?> getProfile(String uid) async {
    final uri = routes.getUserProfile(uid);
    debugPrint('📡 [GET] Profile → $uri');

    try {
      final res = await client.dio.getUri(uri);
      final result = res.data?['result'];

      if (result == null) {
        debugPrint('⚠️ No profile result returned for UID: $uid');
        return null;
      }

      final map = Map<String, dynamic>.from(result);
      final profile = UserProfile.fromMap(uid, map);
      debugPrint('✅ Loaded profile → $uid (${profile.displayName})');
      return profile;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        debugPrint('🕳️ Profile not found → $uid (404)');
        return null;
      }
      debugPrint('❌ Dio error fetching profile → ${e.message}');
      rethrow;
    } catch (e, stack) {
      debugPrint('❌ Unexpected error fetching profile → $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // ✏️ Update arbitrary profile fields
  // ─────────────────────────────────────────────
  Future<void> updateProfileFields({
    required String uid,
    required Map<String, dynamic> fields,
  }) async {
    if (fields.isEmpty) {
      debugPrint('⚠️ Skipped update: No fields provided for UID: $uid');
      return;
    }

    final uri = routes.updateUserProfile(uid);
    debugPrint('📡 [PUT] Update profile → $uri');
    debugPrint('📦 Fields: $fields');

    try {
      final res = await client.dio.putUri(uri, data: fields);
      debugPrint('✅ Profile updated → $uid (${res.statusCode})');
    } on DioException catch (e) {
      debugPrint('❌ Dio error updating profile → ${e.response?.statusCode}');
      debugPrint('📥 Response: ${e.response?.data}');
      rethrow;
    } catch (e, stack) {
      debugPrint('❌ Unexpected error updating profile → $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // 🖼️ Update avatar URL
  // ─────────────────────────────────────────────
  Future<void> updateAvatar(String uid, String avatarUrl) async {
    await updateProfileFields(uid: uid, fields: {'avatarUrl': avatarUrl});
    debugPrint('🖼️ Avatar updated for $uid');
  }

  // ─────────────────────────────────────────────
  // 🛡️ Update user role
  // ─────────────────────────────────────────────
  Future<void> updateUserRole(String uid, String role) async {
    final uri = routes.updateUserRole(uid);
    debugPrint('🛡️ [PUT] Role → $uri ($role)');

    try {
      await client.dio.putUri(uri, data: {'role': role});
      debugPrint('✅ Role updated for $uid → $role');
    } catch (e) {
      debugPrint('❌ Failed to update role for $uid → $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // 🏪 Update assigned store list
  // ─────────────────────────────────────────────
  Future<void> updateUserStores(String uid, List<String> stores) async {
    final uri = routes.updateUserStores(uid);
    debugPrint('🏪 [PUT] Stores → $uri');

    try {
      await client.dio.putUri(uri, data: {'stores': stores});
      debugPrint('✅ Stores updated for $uid → ${stores.join(', ')}');
    } catch (e) {
      debugPrint('❌ Failed to update stores for $uid → $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // 🗑️ Delete profile by UID
  // ─────────────────────────────────────────────
  Future<void> deleteProfile(String uid) async {
    final uri = routes.deleteUserProfile(uid);
    debugPrint('🗑️ [DELETE] Profile → $uri');

    try {
      final res = await client.dio.deleteUri(uri);
      debugPrint('✅ Profile deleted → $uid (${res.statusCode})');
    } on DioException catch (e) {
      debugPrint('❌ Dio error deleting profile → ${e.response?.statusCode}');
      debugPrint('📥 Response: ${e.response?.data}');
      rethrow;
    } catch (e, stack) {
      debugPrint('❌ Unexpected error deleting profile → $e');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }
}
