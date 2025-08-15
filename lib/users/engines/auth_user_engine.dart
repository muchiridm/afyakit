// lib/users/engines/auth_user_engine.dart
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/users/models/auth_user_model.dart';
import 'package:afyakit/users/services/auth_user_service.dart';

class AuthUserEngine {
  final AuthUserService service;
  AuthUserEngine(this.service);

  // ─────────────────────────────────────────────────────────────
  // ✉️ Invites
  // ─────────────────────────────────────────────────────────────
  Future<Result<void>> invite({
    String? email,
    String? phoneNumber,
    bool forceResend = false,
  }) async {
    try {
      await service.inviteUser(
        email: email,
        phoneNumber: phoneNumber,
        forceResend: forceResend,
      );
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/invite-failed', 'Invite failed', cause: e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 👀 Read (service already merges auth_users + user_profiles)
  // ─────────────────────────────────────────────────────────────
  Future<Result<AuthUser>> byId(String uid) async {
    try {
      final user = await service.getUserById(uid);
      return Ok(user);
    } catch (e) {
      return Err(AppError('auth/get-failed', 'Failed to load user', cause: e));
    }
  }

  Future<Result<List<AuthUser>>> all() async {
    try {
      final users = await service.getAllUsers();
      return Ok(users);
    } catch (e) {
      return Err(
        AppError('auth/list-failed', 'Failed to load users', cause: e),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ✏️ Write
  //  - updateFields: single entry-point (service handles unified + legacy split)
  //  - sugar methods call explicit service helpers for clarity
  // ─────────────────────────────────────────────────────────────
  Future<Result<void>> updateFields(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    try {
      await service.updateFields(uid, updates);
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/update-failed', 'Update failed', cause: e));
    }
  }

  Future<Result<void>> setProfile(
    String uid, {
    String? displayName,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    try {
      await service.setProfile(
        uid,
        displayName: displayName,
        phoneNumber: phoneNumber,
        avatarUrl: avatarUrl,
      );
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError(
          'auth/update-profile-failed',
          'Profile update failed',
          cause: e,
        ),
      );
    }
  }

  Future<Result<void>> setRole(String uid, String role) async {
    try {
      // Explicitly call the service helper (which routes to unified + legacy)
      await service.setRole(uid, role);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('auth/update-role-failed', 'Role update failed', cause: e),
      );
    }
  }

  Future<Result<void>> setStores(String uid, List<String> stores) async {
    try {
      await service.setStores(uid, stores);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('auth/update-stores-failed', 'Stores update failed', cause: e),
      );
    }
  }

  Future<Result<void>> activate(String uid) async {
    try {
      await service.activate(uid);
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/activate-failed', 'Activate failed', cause: e));
    }
  }

  Future<Result<void>> disable(String uid) async {
    try {
      await service.disable(uid);
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/disable-failed', 'Disable failed', cause: e));
    }
  }

  /// Convenience: invited → active (+ optional phone)
  Future<Result<void>> promoteInvite(String uid, {String? phoneNumber}) async {
    try {
      await service.updateFields(uid, {
        'status': 'active',
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phoneNumber': phoneNumber,
      });
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('auth/promote-failed', 'Failed to promote invite', cause: e),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 🗑️ Delete (single source of truth)
  // ─────────────────────────────────────────────────────────────
  Future<Result<void>> delete(String uid) async {
    try {
      await service.deleteUser(uid);
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/delete-failed', 'Delete failed', cause: e));
    }
  }
}
