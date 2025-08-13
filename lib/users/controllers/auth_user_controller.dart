// 📂 lib/users/controllers/auth_user_controller.dart
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/shared/providers/tenant_provider.dart';
import 'package:afyakit/shared/providers/api_client_provider.dart';
import 'package:afyakit/users/models/auth_user.dart';
import 'package:afyakit/users/models/user_role_enum.dart';
import 'package:afyakit/users/utils/parse_user_role.dart';
import 'package:afyakit/users/services/auth_user_service.dart';

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

  Future<AuthUserService> _getService() async {
    final tenantId = ref.read(tenantIdProvider);
    final client = await ref.read(apiClientProvider.future);
    return AuthUserService(client: client, routes: ApiRoutes(tenantId));
  }

  Future<void> submit(BuildContext context) => inviteUser(context);

  Future<void> inviteUser(BuildContext context) async {
    final email = EmailHelper.normalize(state.email);

    if (!email.contains('@')) {
      SnackService.showError('Please enter a valid email.');
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final service = await _getService();
      await service.inviteUser(email: email); // 👈 remove uid
      SnackService.showSuccess('✅ Invite sent to $email');
      state = const AuthUserState(); // Reset form
    } catch (e) {
      SnackService.showError('❌ Failed to invite: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> resendInvite({required String email}) async {
    try {
      final service = await _getService();
      await service.inviteUser(
        email: email,
        forceResend: true,
      ); // 👈 added forceResend
      SnackService.showSuccess('✅ Invite resent to $email');
    } catch (e) {
      SnackService.showError('❌ Failed to resend invite: $e');
    }
  }

  Future<void> updateAuthUserFields(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    debugPrint('📡 [Controller] Updating AuthUser fields: $uid');
    debugPrint('📬 Fields: $updates');

    try {
      final service = await _getService();
      await service.updateAuthUserFields(uid, updates);
      debugPrint('✅ [Controller] Update complete');
      SnackService.showSuccess('✅ AuthUser updated');
    } catch (e, st) {
      debugPrint('❌ [Controller] Failed to update AuthUser fields: $e');
      debugPrintStack(stackTrace: st);
      SnackService.showError('❌ Failed to update user');
    }
  }

  Future<List<AuthUser>> getAllUsers() async {
    try {
      final service = await _getService();
      final users = await service.getAllUsers();
      SnackService.showInfo('📋 Loaded ${users.length} users');
      return users;
    } catch (e) {
      SnackService.showError('❌ Failed to load users: $e');
      return [];
    }
  }

  Future<AuthUser?> getUserById(String uid) async {
    try {
      final service = await _getService();
      return await service.getUserById(uid);
    } catch (e) {
      SnackService.showError('❌ Failed to load user: $e');
      return null;
    }
  }
}
