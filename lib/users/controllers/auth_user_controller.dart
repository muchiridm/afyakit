// 📂 lib/users/controllers/auth_user_controller.dart (updated)
import 'package:afyakit/users/providers/user_engine_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/users/models/auth_user_model.dart';
import 'package:afyakit/users/extensions/user_role_enum.dart';
import 'package:afyakit/users/utils/parse_user_role.dart';

// ✨ NEW: engine + provider + result
import 'package:afyakit/users/engines/auth_user_engine.dart';
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';

final authUserControllerProvider =
    StateNotifierProvider.autoDispose<AuthUserController, AuthUserState>(
      (ref) => AuthUserController(ref),
    );

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

class AuthUserController extends StateNotifier<AuthUserState> {
  final Ref ref;
  AuthUserController(this.ref) : super(const AuthUserState());

  // ─────────────────────────────────────────────
  // 🧩 Form setters
  // ─────────────────────────────────────────────
  void setEmail(String email) => state = state.copyWith(email: email);

  void setRole(String roleStr) {
    final parsedRole = parseUserRole(roleStr);
    state = state.copyWith(role: parsedRole);
  }

  void toggleStore(String storeId) {
    final updated = {...state.selectedStoreIds};
    updated.contains(storeId) ? updated.remove(storeId) : updated.add(storeId);
    state = state.copyWith(selectedStoreIds: updated);
  }

  // ─────────────────────────────────────────────
  // ⚙️ Engine wiring (lazy, cached)
  // ─────────────────────────────────────────────
  AuthUserEngine? _engine;
  Future<void> _ensureEngine() async {
    if (_engine != null) return;
    // If you used the FAMILY version of the provider:
    final tenantId = ref.read(tenantIdProvider);
    _engine = await ref.read(authUserEngineProvider(tenantId).future);

    // If you used a non-family FutureProvider instead, use:
    // _engine = await ref.read(authUserEngineProvider.future);
  }

  // Keep signature to avoid breaking callers
  Future<void> submit(BuildContext context) => inviteUser(context);

  // ─────────────────────────────────────────────
  // ✉️ Invite
  // ─────────────────────────────────────────────
  Future<void> inviteUser(BuildContext context) async {
    final email = EmailHelper.normalize(state.email);

    if (!email.contains('@')) {
      SnackService.showError('Please enter a valid email.');
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      await _ensureEngine();
      final res = await _engine!.invite(email);

      if (res is Err<void>) {
        SnackService.showError('❌ Failed to invite: ${res.error.message}');
        return;
      }

      SnackService.showSuccess('✅ Invite sent to $email');
      state = const AuthUserState(); // Reset form
    } catch (e) {
      SnackService.showError('❌ Failed to invite: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // ─────────────────────────────────────────────
  // 🔁 Resend invite
  // ─────────────────────────────────────────────
  Future<void> resendInvite({required String email}) async {
    try {
      await _ensureEngine();
      final res = await _engine!.invite(email, forceResend: true);

      if (res is Err<void>) {
        SnackService.showError(
          '❌ Failed to resend invite: ${res.error.message}',
        );
        return;
      }

      SnackService.showSuccess('✅ Invite resent to $email');
    } catch (e) {
      SnackService.showError('❌ Failed to resend invite: $e');
    }
  }

  // ─────────────────────────────────────────────
  // 🛠️ Update fields
  // ─────────────────────────────────────────────
  Future<void> updateAuthUserFields(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    debugPrint('📡 [Controller] Updating AuthUser fields: $uid');
    debugPrint('📬 Fields: $updates');
    try {
      await _ensureEngine();
      final res = await _engine!.updateFields(uid, updates);

      if (res is Err<void>) {
        debugPrint('❌ [Controller] Update failed: ${res.error.message}');
        SnackService.showError('❌ Failed to update user');
        return;
      }

      debugPrint('✅ [Controller] Update complete');
      SnackService.showSuccess('✅ AuthUser updated');
    } catch (e, st) {
      debugPrint('❌ [Controller] Failed to update AuthUser fields: $e');
      debugPrintStack(stackTrace: st);
      SnackService.showError('❌ Failed to update user');
    }
  }

  // ─────────────────────────────────────────────
  // 👥 Read APIs
  // ─────────────────────────────────────────────
  Future<List<AuthUser>> getAllUsers() async {
    try {
      await _ensureEngine();
      final res = await _engine!.all();

      return switch (res) {
        Ok<List<AuthUser>>(:final value) => value,
        Err<List<AuthUser>>() => <AuthUser>[],
      };
    } catch (e) {
      SnackService.showError('❌ Failed to load users: $e');
      return [];
    }
  }

  Future<AuthUser?> getUserById(String uid) async {
    try {
      await _ensureEngine();
      final res = await _engine!.byId(uid);

      return switch (res) {
        Ok<AuthUser?>(:final value) => value,
        Err<AuthUser?>() => null,
      };
    } catch (e) {
      SnackService.showError('❌ Failed to load user: $e');
      return null;
    }
  }
}
