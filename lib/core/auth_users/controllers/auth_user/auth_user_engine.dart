import 'package:afyakit/api/api_client.dart';
import 'package:afyakit/api/api_routes.dart';
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/shared/types/app_error.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';

import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/extensions/user_role_x.dart';
import 'package:afyakit/core/auth_users/extensions/user_status_x.dart';

import 'package:afyakit/core/auth_users/services/auth_user_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authUserEngineProvider = FutureProvider.family<AuthUserEngine, String>((
  ref,
  tenantId,
) async {
  // Authenticated ApiClient (already tenant-aware via tenantIdProvider)
  final client = await ref.read(apiClientProvider.future);

  // Tenant-scoped routes & service
  final routes = ApiRoutes(tenantId);
  final tenantSvc = AuthUserService(client: client, routes: routes);
  return AuthUserEngine(tenantSvc);
});

/// Tenant-only engine: invites, reads, updates, deletes.
/// All writes go through a single generic PATCH.
class AuthUserEngine {
  final AuthUserService _svc;
  AuthUserEngine(this._svc);

  // ─────────────────────────────────────────────────────────────
  // Invites
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
      final resolvedRole = _parseRole(role);
      await _svc.inviteUser(
        email: (email == null || email.trim().isEmpty)
            ? null
            : EmailHelper.normalize(email),
        phoneNumber: (phoneNumber == null || phoneNumber.trim().isEmpty)
            ? null
            : phoneNumber.trim(),
        role: resolvedRole,
        forceResend: forceResend,
      );
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/invite-failed', 'Invite failed', cause: e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Reads (tenant-scoped)
  // ─────────────────────────────────────────────────────────────
  Future<Result<AuthUser>> byId(String uid) async {
    try {
      final user = await _svc.getUserById(uid);
      return Ok(user);
    } catch (e) {
      return Err(AppError('auth/get-failed', 'Failed to load user', cause: e));
    }
  }

  Future<Result<List<AuthUser>>> all() async {
    try {
      final users = await _svc.getAllUsers();
      return Ok(users);
    } catch (e) {
      return Err(
        AppError('auth/list-failed', 'Failed to load users', cause: e),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Generic write (profile / role / status / stores / email/phone)
  // Supported keys: displayName, phoneNumber, avatarUrl, role, status, stores, email
  // ─────────────────────────────────────────────────────────────
  Future<Result<void>> updateFields(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    try {
      final body = _normalizeUpdatePayload(updates);
      await _svc.updateUserFields(uid, body);
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/update-failed', 'Update failed', cause: e));
    }
  }

  // Convenience wrappers (implemented via generic PATCH)
  Future<Result<void>> setProfile(
    String uid, {
    String? displayName,
    String? phoneNumber,
    String? avatarUrl,
  }) => updateFields(uid, {
    if (displayName != null) 'displayName': displayName,
    if (phoneNumber != null) 'phoneNumber': phoneNumber,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
  });

  Future<Result<void>> setRole(String uid, String role) =>
      updateFields(uid, {'role': role});

  Future<Result<void>> setStores(String uid, List<String> stores) =>
      updateFields(uid, {'stores': stores});

  Future<Result<void>> activate(String uid) =>
      updateFields(uid, {'status': 'active'});

  Future<Result<void>> disable(String uid) =>
      updateFields(uid, {'status': 'disabled'});

  /// Convenience: invited → active (optionally set phone in same PATCH)
  Future<Result<void>> promoteInvite(String uid, {String? phoneNumber}) =>
      updateFields(uid, {
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phoneNumber': phoneNumber.trim(),
        'status': 'active',
      });

  // ─────────────────────────────────────────────────────────────
  // Delete (tenant membership)
  // ─────────────────────────────────────────────────────────────
  Future<Result<void>> delete(String uid) async {
    try {
      await _svc.deleteUser(uid);
      return const Ok(null);
    } catch (e) {
      return Err(AppError('auth/delete-failed', 'Delete failed', cause: e));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // helpers
  // ─────────────────────────────────────────────────────────────
  UserRole _parseRole(String? r) {
    if (r == null || r.trim().isEmpty) return UserRole.staff;
    switch (r.trim().toLowerCase()) {
      case 'owner':
        return UserRole.owner;
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'client':
        return UserRole.client;
      case 'staff':
      default:
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

  /// Normalize arbitrary UI updates to the backend PATCH shape.

  Map<String, Object?> _normalizeUpdatePayload(Map<String, dynamic> src) {
    final out = <String, Object?>{};
    String? s(Object? v) {
      if (v == null) return null;
      final t = v.toString().trim();
      return t.isEmpty ? null : t;
    }

    // strings
    final displayName = s(src['displayName']);
    final phoneNumber = s(src['phoneNumber']);
    final avatarUrl = s(src['avatarUrl']);
    final email = s(src['email']);
    final roleStr = s(src['role']);
    final statusStr = s(src['status']);

    if (displayName != null) out['displayName'] = displayName;
    if (phoneNumber != null) out['phoneNumber'] = phoneNumber;
    if (avatarUrl != null) out['avatarUrl'] = avatarUrl;
    if (email != null) out['email'] = EmailHelper.normalize(email);
    if (roleStr != null) out['role'] = _parseRole(roleStr).wire;
    if (statusStr != null) out['status'] = _parseStatus(statusStr).wire;

    // ── STORES: DO NOT DROP EMPTY ────────────────────────────────
    final storesRaw = src['stores'];
    if (storesRaw is List) {
      final stores = storesRaw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      out['stores'] = stores; // <-- include [], clears stores on server
    } else if (storesRaw is String) {
      final stores = storesRaw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      out['stores'] = stores; // can also be []
    }

    return out;
  }
}
