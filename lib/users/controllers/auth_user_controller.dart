// 📂 lib/users/controllers/auth_user_controller.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';

import 'package:afyakit/users/models/auth_user_model.dart';
import 'package:afyakit/users/extensions/user_role_enum.dart';
import 'package:afyakit/users/utils/parse_user_role.dart';

import 'package:afyakit/users/engines/auth_user_engine.dart';
import 'package:afyakit/users/providers/user_engine_providers.dart';
import 'package:afyakit/shared/types/result.dart';

final authUserControllerProvider =
    StateNotifierProvider.autoDispose<AuthUserController, AuthUserState>(
      (ref) => AuthUserController(ref),
    );

// ─────────────────────────────────────────────────────────────
// 🧠 Local form state (lightweight)
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
// 🎛️ Controller
// ─────────────────────────────────────────────────────────────
class AuthUserController extends StateNotifier<AuthUserState> {
  final Ref ref;
  AuthUserController(this.ref) : super(const AuthUserState());

  // Form setters
  void setEmail(String email) => state = state.copyWith(email: email);

  // UI-only
  void setFormRole(UserRole role) {
    state = state.copyWith(role: role);
  }

  void setFormRoleFromString(String roleStr) {
    state = state.copyWith(role: parseUserRole(roleStr));
  }

  void toggleStore(String storeId) {
    final updated = {...state.selectedStoreIds};
    updated.contains(storeId) ? updated.remove(storeId) : updated.add(storeId);
    state = state.copyWith(selectedStoreIds: updated);
  }

  // Engine
  AuthUserEngine? _engine;
  Future<void> _ensureEngine() async {
    if (_engine != null) return;
    final tenantId = ref.read(tenantIdProvider);
    _engine = await ref.read(authUserEngineProvider(tenantId).future);
  }

  // Keep this for existing callers
  Future<void> submit(BuildContext context) => inviteUser(context);

  // ─────────────────────────────────────────────────────────────
  // ✉️ Invite (email and/or phone)
  // ─────────────────────────────────────────────────────────────
  Future<void> inviteUser(BuildContext context, {String? phoneNumber}) async {
    final rawEmail = state.email;
    final email = rawEmail.isNotEmpty ? EmailHelper.normalize(rawEmail) : '';

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

      final idLabel = email.isNotEmpty
          ? email
          : (phoneNumber ?? '(no identifier)');
      SnackService.showSuccess('✅ Invite sent to $idLabel');
      state = const AuthUserState(); // reset form
    } catch (e) {
      SnackService.showError('❌ Failed to invite: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 🔁 Re-send invite
  // ─────────────────────────────────────────────────────────────
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

      final idLabel = (email != null && email.isNotEmpty)
          ? email
          : (phoneNumber ?? '');
      SnackService.showSuccess('✅ Invite resent to $idLabel');
    } catch (e) {
      SnackService.showError('❌ Failed to resend invite: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 🛠️ Update fields (unified)
  // ─────────────────────────────────────────────────────────────
  Future<void> updateFields(String uid, Map<String, dynamic> updates) async {
    debugPrint('📡 [AuthUserController] updateFields uid=$uid fields=$updates');
    try {
      await _ensureEngine();
      final res = await _engine!.updateFields(uid, updates);
      if (res is Err<void>) {
        debugPrint(
          '❌ [AuthUserController] Update failed: ${res.error.message}',
        );
        SnackService.showError('❌ Failed to update user');
        return;
      }
      debugPrint('✅ [AuthUserController] Update complete');
      SnackService.showSuccess('✅ User updated');
    } catch (e, st) {
      debugPrint('❌ [AuthUserController] Exception: $e');
      debugPrintStack(stackTrace: st);
      SnackService.showError('❌ Failed to update user');
    }
  }

  // 🍬 sugar
  // Server write
  Future<void> updateUserRole(String uid, {UserRole? role}) async {
    await _ensureEngine();
    final target = (role ?? state.role).name;
    final res = await _engine!.setRole(uid, target); // or updateFields
    if (res is Err<void>) {
      SnackService.showError('❌ Failed to update role: ${res.error.message}');
      return;
    }
    SnackService.showSuccess('✅ Role updated');
  }

  Future<void> setStores(String uid, List<String> stores) =>
      updateFields(uid, {'stores': stores});

  // ─────────────────────────────────────────────────────────────
  // 👥 Read APIs
  // ─────────────────────────────────────────────────────────────
  Future<List<AuthUser>> getAllUsers() async {
    try {
      await _ensureEngine();
      final res = await _engine!.all();
      if (res is Ok<List<AuthUser>>) {
        final users = res.value;
        debugPrint('✅ [AuthUserController] Loaded ${users.length} users');
        return users;
      } else if (res is Err<List<AuthUser>>) {
        debugPrint('❌ [AuthUserController] Load failed: ${res.error.message}');
        return <AuthUser>[];
      }
      // Safety (shouldn’t hit)
      return <AuthUser>[];
    } catch (e) {
      SnackService.showError('❌ Failed to load users: $e');
      return <AuthUser>[];
    }
  }

  Future<AuthUser?> getUserById(String uid) async {
    try {
      await _ensureEngine();
      final res = await _engine!.byId(uid);
      if (res is Ok<AuthUser>) return res.value;
      if (res is Err<AuthUser>) {
        debugPrint('❌ [AuthUserController] byId failed: ${res.error.message}');
        return null;
      }
      return null;
    } catch (e) {
      SnackService.showError('❌ Failed to load user: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 🗑️ Delete user (single source of truth)
  // ─────────────────────────────────────────────────────────────
  Future<void> deleteUser(String uid) async {
    try {
      await _ensureEngine();

      // Ensure your AuthUserEngine exposes a matching delete API.
      // If it's named differently (e.g., remove/deleteById), just swap it here.
      final res = await _engine!.delete(uid);

      if (res is Err<void>) {
        SnackService.showError('❌ Failed to delete user: ${res.error.message}');
        return;
      }
    } catch (e, st) {
      debugPrint('❌ [AuthUserController] deleteUser exception: $e');
      debugPrintStack(stackTrace: st);
      SnackService.showError('❌ Failed to delete user');
    }
  }
}
