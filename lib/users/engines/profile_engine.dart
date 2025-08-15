// lib/users/engines/profile_engine.dart
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/users/models/user_profile_model.dart';
import 'package:afyakit/users/services/user_profile_service.dart';
import 'package:afyakit/users/services/auth_user_service.dart';

class ProfileEngine {
  final UserProfileService profiles;
  final AuthUserService authUsers;

  ProfileEngine({required this.profiles, required this.authUsers});

  Future<Result<UserProfile?>> getProfile(String uid) async {
    try {
      return Ok(await profiles.getProfile(uid));
    } catch (e) {
      return Err(
        AppError('profile/get-failed', 'Failed to fetch profile', cause: e),
      );
    }
  }

  Future<Result<void>> updateProfile(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    try {
      if (fields.isEmpty) return const Ok(null);
      await profiles.updateProfileFields(uid: uid, fields: fields);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('profile/update-failed', 'Profile update failed', cause: e),
      );
    }
  }

  Future<Result<void>> updateRole(String uid, String role) async {
    try {
      await profiles.updateUserRole(uid, role);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('profile/role-failed', 'Role update failed', cause: e),
      );
    }
  }

  Future<Result<void>> updateStores(String uid, List<String> stores) async {
    try {
      await profiles.updateUserStores(uid, stores);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('profile/stores-failed', 'Store update failed', cause: e),
      );
    }
  }

  /// Convenience for “promote invited → active + phone update”
  Future<Result<void>> promoteInviteAndPatchAuth(
    String uid, {
    String? phoneNumber,
  }) async {
    try {
      final updates = <String, dynamic>{'status': 'active'};
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        updates['phoneNumber'] = phoneNumber;
      }
      await authUsers.updateAuthUserFields(uid, updates);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('auth/promote-failed', 'Failed to promote invite', cause: e),
      );
    }
  }
}
