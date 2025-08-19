import 'dart:async';
import 'package:afyakit/users/user_manager/extensions/user_role_x.dart';
import 'package:afyakit/users/user_manager/models/super_admim_model.dart';
import 'package:afyakit/users/user_manager/providers/user_engine_providers.dart';
import 'package:afyakit/users/utils/parse_user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';

import 'package:afyakit/users/user_manager/models/auth_user_model.dart';
import 'package:afyakit/users/user_manager/engines/user_manager_engine.dart';
import 'package:afyakit/shared/types/result.dart';

final userManagerControllerProvider =
    StateNotifierProvider.autoDispose<UserManagerController, AuthUserState>(
      (ref) => UserManagerController(ref),
    );

// ─────────────────────────────────────────────────────────────
// 🧠 State (form-only; reads use Firestore providers)
// ─────────────────────────────────────────────────────────────
class AuthUserState {
  final String email;
  final UserRole role;
  final Set<String> selectedStoreIds;
  final bool isLoading;

  const AuthUserState({
    this.email = '',
    this.role = UserRole.staff,
    this.selectedStoreIds = const {},
    this.isLoading = false,
  });

  AuthUserState copyWith({
    String? email,
    UserRole? role,
    Set<String>? selectedStoreIds,
    bool? isLoading,
  }) {
    return AuthUserState(
      email: email ?? this.email,
      role: role ?? this.role,
      selectedStoreIds: selectedStoreIds ?? this.selectedStoreIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 🎛️ Controller (mutations only)
// ─────────────────────────────────────────────────────────────
class UserManagerController extends StateNotifier<AuthUserState> {
  final Ref ref;
  UserManagerController(this.ref) : super(const AuthUserState());

  UserManagerEngine? _engine;
  Future<void> _ensureEngine() async {
    if (_engine != null) return;
    final tenantId = ref.read(tenantIdProvider);
    _engine = await ref.read(userManagerEngineProvider(tenantId).future);
  }

  // Form setters
  void setEmail(String email) => state = state.copyWith(email: email);
  void setFormRole(UserRole role) => state = state.copyWith(role: role);
  void toggleStore(String storeId) {
    final updated = {...state.selectedStoreIds};
    updated.contains(storeId) ? updated.remove(storeId) : updated.add(storeId);
    state = state.copyWith(selectedStoreIds: updated);
  }

  Future<void> submit(BuildContext ctx) => inviteUser(ctx);

  // Invites
  Future<void> inviteUser(BuildContext context, {String? phoneNumber}) async {
    final raw = state.email;
    final email = raw.isNotEmpty ? EmailHelper.normalize(raw) : '';

    if (email.isEmpty && (phoneNumber == null || phoneNumber.trim().isEmpty)) {
      SnackService.showError('Please enter an email or phone number.');
      return;
    }
    if (email.isNotEmpty && !email.contains('@')) {
      SnackService.showError('Please enter a valid email.');
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      await _ensureEngine();
      final res = await _engine!.invite(
        email: email.isNotEmpty ? email : null,
        phoneNumber: phoneNumber?.trim().isEmpty == true ? null : phoneNumber,
        forceResend: false,
      );
      if (res is Err<void>) {
        SnackService.showError('❌ Failed to invite: ${res.error.message}');
        return;
      }
      SnackService.showSuccess('✅ Invite sent');
      state = const AuthUserState(); // reset form
    } catch (e) {
      SnackService.showError('❌ Failed to invite: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> resendInvite({String? email, String? phoneNumber}) async {
    if ((email == null || email.trim().isEmpty) &&
        (phoneNumber == null || phoneNumber.trim().isEmpty)) {
      SnackService.showError('Provide email or phone to resend.');
      return;
    }
    try {
      await _ensureEngine();
      final res = await _engine!.invite(
        email: (email != null && email.trim().isNotEmpty)
            ? EmailHelper.normalize(email)
            : null,
        phoneNumber: (phoneNumber != null && phoneNumber.trim().isNotEmpty)
            ? phoneNumber
            : null,
        forceResend: true,
      );
      if (res is Err<void>) {
        SnackService.showError('❌ Failed to resend: ${res.error.message}');
        return;
      }
      SnackService.showSuccess('✅ Invite resent');
    } catch (e) {
      SnackService.showError('❌ Failed to resend invite: $e');
    }
  }

  // Mutations
  Future<void> updateFields(String uid, Map<String, dynamic> updates) async {
    try {
      await _ensureEngine();
      final res = await _engine!.updateFields(uid, updates);
      if (res is Err<void>) {
        SnackService.showError('❌ Failed to update user');
        return;
      }
      SnackService.showSuccess('✅ User updated');
    } catch (e) {
      SnackService.showError('❌ Failed to update user: $e');
    }
  }

  Future<void> updateUserRole(String uid, {UserRole? role}) async {
    await _ensureEngine();
    final target = (role ?? state.role).name;
    final res = await _engine!.setRole(uid, target);
    if (res is Err<void>) {
      SnackService.showError('❌ Failed to update role: ${res.error.message}');
      return;
    }
    SnackService.showSuccess('✅ Role updated');
  }

  Future<void> setStores(String uid, List<String> stores) =>
      updateFields(uid, {'stores': stores});

  void setFormRoleFromString(String roleStr) =>
      setFormRole(parseUserRole(roleStr));

  Future<List<AuthUser>> getAllUsers() async {
    try {
      await _ensureEngine();
      final res = await _engine!.all();
      return res is Ok<List<AuthUser>> ? res.value : <AuthUser>[];
    } catch (_) {
      SnackService.showError('❌ Failed to load users');
      return <AuthUser>[];
    }
  }

  Future<AuthUser?> getUserById(String uid) async {
    try {
      await _ensureEngine();
      final res = await _engine!.byId(uid);
      return res is Ok<AuthUser> ? res.value : null;
    } catch (_) {
      SnackService.showError('❌ Failed to load user');
      return null;
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      await _ensureEngine();
      final res = await _engine!.delete(uid);
      if (res is Err<void>) {
        SnackService.showError('❌ Failed to delete user: ${res.error.message}');
      }
    } catch (_) {
      SnackService.showError('❌ Failed to delete user');
    }
  }

  // HQ: Superadmins
  Future<List<SuperAdmin>> listSuperAdmins() async {
    await _ensureEngine();
    final res = await _engine!.listSuperAdmins();
    if (res is Ok<List<SuperAdmin>>) return res.value;
    final msg = (res as Err<List<SuperAdmin>>).error.message;
    SnackService.showError('❌ Failed to load superadmins: $msg');
    throw Exception(msg);
  }

  Future<void> promoteSuperAdmin(String uid) async {
    await _ensureEngine();
    final r = await _engine!.setSuperAdmin(uid: uid, value: true);
    if (r is Err<void>) {
      SnackService.showError('❌ Promote failed: ${r.error.message}');
      return;
    }
    SnackService.showSuccess('✅ Promoted');
  }

  Future<void> demoteSuperAdmin(String uid) async {
    await _ensureEngine();
    final r = await _engine!.setSuperAdmin(uid: uid, value: false);
    if (r is Err<void>) {
      SnackService.showError('❌ Demote failed: ${r.error.message}');
      return;
    }
    SnackService.showSuccess('✅ Demoted');
  }
}
