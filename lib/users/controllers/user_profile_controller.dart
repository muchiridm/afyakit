import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/api/api_client.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/users/models/user_profile_model.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:afyakit/users/services/user_profile_service.dart';

/// 🧠 Provides UserProfileController with scoped tenantId
final userProfileControllerProvider =
    FutureProvider.family<UserProfileController, String>((ref, tenantId) async {
      final tokenProviderInstance = ref.read(tokenProvider);

      final client = await ApiClient.create(
        tenantId: tenantId,
        tokenProvider: tokenProviderInstance,
      );

      final service = UserProfileService(
        client: client,
        routes: ApiRoutes(tenantId),
      );

      return UserProfileController(service);
    });

class UserProfileController {
  final UserProfileService _service;

  UserProfileController(this._service);

  // ───────────────────────────────────────────────
  // 🔍 Get profile by UID
  // ───────────────────────────────────────────────
  Future<UserProfile?> getProfile(String uid) async {
    debugPrint('📥 Fetching profile for UID: $uid');
    try {
      final profile = await _service.getProfile(uid);
      if (profile == null) {
        debugPrint('⚠️ No profile found for UID: $uid');
      } else {
        debugPrint('✅ Profile loaded → ${profile.displayName}');
      }
      return profile;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      debugPrint('❌ Dio error while fetching profile: ${e.message}');
      rethrow;
    } catch (e, st) {
      debugPrint('❌ Unexpected error while fetching profile');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  // ───────────────────────────────────────────────
  // ✏️ Generic update for displayName, phone, avatar
  // ───────────────────────────────────────────────
  Future<void> updateUserProfile(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    if (fields.isEmpty) return;

    try {
      await _service.updateProfileFields(uid: uid, fields: fields);
      SnackService.showSuccess('✅ Profile updated');
    } catch (e) {
      SnackService.showError('❌ Failed to update profile: $e');
      rethrow;
    }
  }

  // 🔧 Optional shortcuts for common fields
  Future<void> updateDisplayName(String uid, String displayName) =>
      updateUserProfile(uid, {'displayName': displayName});

  Future<void> updatePhone(String uid, String phone) =>
      updateUserProfile(uid, {'phone': phone});

  Future<void> updateAvatar(String uid, String avatarUrl) =>
      updateUserProfile(uid, {'avatarUrl': avatarUrl});

  // ───────────────────────────────────────────────
  // 🛠️ Role update (with confirmation)
  // ───────────────────────────────────────────────
  Future<void> updateUserRole(String uid, String role) async {
    final confirmed = await DialogService.confirm(
      title: 'Change Role',
      content: 'Are you sure you want to change this user’s role to "$role"?',
    );
    if (confirmed != true) return;

    try {
      await _service.updateUserRole(uid, role);
      SnackService.showSuccess('✅ Role updated');
    } catch (e) {
      SnackService.showError('❌ Failed to update role: $e');
      rethrow;
    }
  }

  // ───────────────────────────────────────────────
  // 🏪 Store access update
  // ───────────────────────────────────────────────
  Future<void> updateUserStores(String uid, List<String> stores) async {
    try {
      await _service.updateUserStores(uid, stores);
      SnackService.showSuccess('✅ Store access updated');
    } catch (e) {
      SnackService.showError('❌ Failed to update stores: $e');
      rethrow;
    }
  }
}
