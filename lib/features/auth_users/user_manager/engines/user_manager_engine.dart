// lib/users/user_manager/engines/user_manager_engine.dart

import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';

import 'package:afyakit/features/auth_users/models/auth_user_model.dart';
import 'package:afyakit/features/auth_users/models/global_user_model.dart';
import 'package:afyakit/features/auth_users/models/super_admim_model.dart';

import 'package:afyakit/features/auth_users/user_manager/extensions/user_role_x.dart';
import 'package:afyakit/features/auth_users/user_manager/extensions/user_status_x.dart';

import 'package:afyakit/features/auth_users/user_manager/services/user_manager_service.dart';
import 'package:afyakit/features/auth_users/user_manager/services/global_users_service.dart';
import 'package:afyakit/features/auth_users/user_manager/services/dtos.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';

class UserManagerEngine {
  final UserManagerService _tenantService;
  final GlobalUsersService? _hqService; // optional for backward compat

  UserManagerEngine(this._tenantService, [this._hqService]);

  // Force a fresh ID token so custom claims (e.g. superadmin) are present.
  Future<void> _ensureFreshToken() async {
    final u = fb.FirebaseAuth.instance.currentUser;
    if (u != null) {
      try {
        await u.getIdToken(true); // force refresh
      } catch (_) {
        // best-effort; backend will still 403 if truly unauthorized
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ✉️ Invites (string role → enum, tolerant)
  // ─────────────────────────────────────────────────────────────
  Future<Result<void>> invite({
    String? email,
    String? phoneNumber,
    String? role, // 'owner'|'admin'|'manager'|'staff'|'client'|null
    bool forceResend = false,
  }) async {
    try {
      if ((email == null || email.isEmpty) &&
          (phoneNumber == null || phoneNumber.isEmpty)) {
        return Err(AppError('auth/bad-invite', 'Email or phone is required'));
      }

      final UserRole resolvedRole = _parseRole(role);

      await _tenantService.inviteUser(
        email: email,
        phoneNumber: phoneNumber,
        role: resolvedRole,
        forceResend: forceResend,
      );
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/invite-failed', 'Invite failed', cause: e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 👀 Read (tenant-scoped)
  // ─────────────────────────────────────────────────────────────
  Future<Result<AuthUser>> byId(String uid) async {
    try {
      final user = await _tenantService.getUserById(uid);
      return Ok(user);
    } catch (e) {
      return Err(AppError('auth/get-failed', 'Failed to load user', cause: e));
    }
  }

  Future<Result<List<AuthUser>>> all() async {
    try {
      final users = await _tenantService.getAllUsers();
      return Ok(users);
    } catch (e) {
      return Err(
        AppError('auth/list-failed', 'Failed to load users', cause: e),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ✏️ Write (splits into profile / membership calls)
  // Supported keys: displayName, phoneNumber, avatarUrl, role, status, stores
  // ─────────────────────────────────────────────────────────────
  Future<Result<void>> updateFields(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    try {
      String? s0(String key) {
        final v = updates[key];
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      // profile
      final profileReq = UpdateProfileRequest(
        displayName: s0('displayName'),
        phoneNumber: s0('phoneNumber'),
        avatarUrl: s0('avatarUrl'),
      );
      if (profileReq.toJson().isNotEmpty) {
        await _tenantService.updateProfile(uid, profileReq);
      }

      // role
      final roleStr = s0('role');
      if (roleStr != null) {
        await _tenantService.assignRole(uid, _parseRole(roleStr));
      }

      // status
      final statusStr = s0('status');
      if (statusStr != null) {
        await _tenantService.setStatus(uid, _parseStatus(statusStr));
      }

      // stores
      final storesRaw = updates['stores'];
      final List<String>? stores = switch (storesRaw) {
        List l =>
          l.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList(),
        String s when s.trim().isNotEmpty =>
          s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        _ => null,
      };
      if (stores != null) {
        await _tenantService.setStores(uid, stores);
      }

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
      final req = UpdateProfileRequest(
        displayName: displayName,
        phoneNumber: phoneNumber,
        avatarUrl: avatarUrl,
      );
      await _tenantService.updateProfile(uid, req);
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
      await _tenantService.assignRole(uid, _parseRole(role));
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('auth/update-role-failed', 'Role update failed', cause: e),
      );
    }
  }

  Future<Result<void>> setStores(String uid, List<String> stores) async {
    try {
      await _tenantService.setStores(uid, stores);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('auth/update-stores-failed', 'Stores update failed', cause: e),
      );
    }
  }

  Future<Result<void>> activate(String uid) async {
    try {
      await _tenantService.activateUser(uid);
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/activate-failed', 'Activate failed', cause: e));
    }
  }

  Future<Result<void>> disable(String uid) async {
    try {
      await _tenantService.disableUser(uid);
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/disable-failed', 'Disable failed', cause: e));
    }
  }

  /// Convenience: invited → active (+ optional phone)
  Future<Result<void>> promoteInvite(String uid, {String? phoneNumber}) async {
    try {
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
        await _tenantService.updateProfile(
          uid,
          UpdateProfileRequest(phoneNumber: phoneNumber.trim()),
        );
      }
      await _tenantService.activateUser(uid);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError('auth/promote-failed', 'Failed to promote invite', cause: e),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 🗑️ Delete (tenant membership)
  // ─────────────────────────────────────────────────────────────
  Future<Result<void>> delete(String uid) async {
    try {
      await _tenantService.deleteUser(uid);
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/delete-failed', 'Delete failed', cause: e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HQ / Global (requires GlobalUsersService)
  // ─────────────────────────────────────────────────────────────
  bool get hasHq => _hqService != null;

  GlobalUsersService get _hqOrThrow {
    final s = _hqService;
    if (s == null) {
      // Make this obvious in FE logs
      debugPrint(
        '❌ [UserManagerEngine] HQ service is NOT configured. '
        'HQ/global methods are unavailable.',
      );
      throw StateError('hq/service-missing');
    }
    return s;
  }

  Future<Result<List<GlobalUser>>> hqUsers({
    String? tenantId,
    String search = '',
    int limit = 50,
  }) async {
    try {
      await _ensureFreshToken();
      final list = await _hqOrThrow.fetchGlobalUsers(
        tenantId: tenantId,
        search: search,
        limit: limit,
      );
      return Ok(list);
    } catch (e) {
      return Err(
        AppError('hq/users-failed', 'Failed to load global users', cause: e),
      );
    }
  }

  Future<Result<Map<String, Map<String, Object?>>>> fetchUserMemberships(
    String uid,
  ) async {
    try {
      await _ensureFreshToken();
      final map = await _hqOrThrow.fetchUserMemberships(uid);
      return Ok(map);
    } catch (e) {
      return Err(
        AppError(
          'hq/memberships-failed',
          'Failed to load memberships',
          cause: e,
        ),
      );
    }
  }

  Future<Result<List<SuperAdmin>>> listSuperAdmins() async {
    try {
      await _ensureFreshToken();
      final list = await _hqOrThrow.listSuperAdmins();
      return Ok(list);
    } catch (e) {
      return Err(
        AppError(
          'hq/superadmins-list-failed',
          'Failed to load superadmins',
          cause: e,
        ),
      );
    }
  }

  Future<Result<void>> setSuperAdmin({
    required String uid,
    required bool value,
  }) async {
    try {
      await _ensureFreshToken();
      await _hqOrThrow.setSuperAdmin(uid: uid, value: value);
      return const Ok(null);
    } catch (e) {
      return Err(
        AppError(
          'hq/superadmins-set-failed',
          'Failed to update superadmin',
          cause: e,
        ),
      );
    }
  }

  Future<Result<InviteResult>> hqInviteUserForTenant({
    required String targetTenantId,
    String? email,
    String? phoneNumber,
    String? role, // parsed/tolerant -> UserRole
    String? brandBaseUrl,
    bool forceResend = false,
  }) async {
    try {
      await _ensureFreshToken();

      final cleanedEmail = (email ?? '').trim();
      final cleanedPhone = (phoneNumber ?? '').trim();
      if (cleanedEmail.isEmpty && cleanedPhone.isEmpty) {
        return Err(AppError('hq/bad-invite', 'Email or phone is required'));
      }

      final resolvedRole = _parseRole(role);
      final result = await _hqOrThrow.inviteUserForTenant(
        targetTenantId: targetTenantId,
        email: cleanedEmail.isEmpty ? null : cleanedEmail,
        phoneNumber: cleanedPhone.isEmpty ? null : cleanedPhone,
        role: resolvedRole,
        brandBaseUrl: brandBaseUrl,
        forceResend: forceResend,
      );
      return Ok(result);
    } catch (e) {
      return Err(AppError('hq/invite-failed', 'HQ invite failed', cause: e));
    }
  }

  Future<Result<void>> hqDeleteUserFromTenant({
    required String targetTenantId,
    required String uid,
  }) async {
    try {
      await _ensureFreshToken();
      await _hqOrThrow.deleteUserForTenant(targetTenantId, uid);
      return const Ok(null);
    } catch (e) {
      return Err(AppError('hq/delete-failed', 'HQ delete failed', cause: e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // helpers
  // ─────────────────────────────────────────────────────────────
  UserRole _parseRole(String? r) {
    if (r == null || r.trim().isEmpty) return UserRole.staff;
    final s = r.trim().toLowerCase();
    switch (s) {
      case 'owner':
        return UserRole.owner;
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'client':
        return UserRole.client;
      case 'staff':
        return UserRole.staff;
      default:
        // default to staff to match backend + FE defaults
        return UserRole.staff;
    }
  }

  UserStatus _parseStatus(String s) {
    switch (s.trim().toLowerCase()) {
      case 'active':
        return UserStatus.active;
      case 'disabled':
        return UserStatus.disabled;
      case 'invited':
      default:
        return UserStatus.invited;
    }
  }
}
