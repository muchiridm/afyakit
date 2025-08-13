// 📁 features/user_profiles/controllers/profile_editor_controller.dart

import 'package:collection/collection.dart';
import 'package:afyakit/shared/utils/normalize/normalize_phone.dart';
import 'package:afyakit/users/controllers/auth_user_controller.dart';
import 'package:afyakit/users/controllers/user_session_controller.dart';
import 'package:afyakit/users/models/auth_user_status_enum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/users/models/combined_user.dart';
import 'package:afyakit/shared/providers/tenant_provider.dart';
import 'package:afyakit/shared/providers/users/combined_user_provider.dart';
import 'package:afyakit/shared/providers/users/combined_user_stream_provider.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/users/controllers/user_profile_controller.dart';

// 🔧 Controller with optional UID (for invite flows)
final userProfileEditorControllerProvider =
    StateNotifierProvider.family<
      UserProfileEditorController,
      AsyncValue<void>,
      String?
    >(
      (ref, inviteUid) =>
          UserProfileEditorController(ref, inviteUid: inviteUid),
    );

// 🔍 Helper to lookup a user by UID from live stream
final combinedUserByIdProvider = Provider.family<CombinedUser?, String>((
  ref,
  uid,
) {
  final allUsers = ref.watch(combinedUserStreamProvider);
  return allUsers.maybeWhen(
    data: (users) => users.firstWhereOrNull((u) => u.uid == uid),
    orElse: () => null,
  );
});

class UserProfileEditorController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  final String? inviteUid;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  CombinedUser? _user;
  bool _initialized = false;

  CombinedUser? get user => _user;

  UserProfileEditorController(this.ref, {this.inviteUid})
    : super(const AsyncData(null)) {
    _init();
  }

  void _init() {
    if (_initialized) return;

    final currentUser = ref.read(combinedUserProvider).asData?.value;
    if (currentUser != null) {
      _user = currentUser;
    } else if (inviteUid != null) {
      _user = ref.read(combinedUserByIdProvider(inviteUid!));
    }

    if (_user != null) {
      nameController.text = _user!.displayName;
      phoneController.text = _user!.phoneNumber ?? '';
      _initialized = true;
    }
  }

  /// 🔄 Save profile changes to backend

  Future<bool> submit(BuildContext context) async {
    final name = nameController.text.trim();
    final rawPhone = phoneController.text.trim();
    final phone = normalizePhone(rawPhone);

    debugPrint('📥 Submitting profile...');
    debugPrint('👤 Name: $name');
    debugPrint('📞 Raw Phone: $rawPhone → Normalized: $phone');

    if (name.isEmpty) {
      SnackService.showError('Display name is required');
      return false;
    }

    final user = _user;
    if (user == null) {
      SnackService.showError('⚠️ No user loaded.');
      return false;
    }

    state = const AsyncLoading();

    try {
      final tenantId = ref.read(tenantIdProvider);

      final profileController = await ref.read(
        userProfileControllerProvider(tenantId).future,
      );
      final authUserController = ref.read(authUserControllerProvider.notifier);
      final sessionController = ref.read(
        userSessionControllerProvider(tenantId).notifier,
      );

      // ─────────────────────────────────────────────
      // 👤 Update UserProfile
      // ─────────────────────────────────────────────
      final profilePayload = {
        'displayName': name,
        'avatarUrl': user.avatarUrl ?? '',
        'role': user.role.name,
      };
      debugPrint('📦 Updating UserProfile → $profilePayload');
      await profileController.updateUserProfile(user.uid, profilePayload);

      // ─────────────────────────────────────────────
      // 🔄 Prepare AuthUser updates
      // ─────────────────────────────────────────────
      final updateFields = <String, dynamic>{};

      if (phone != user.phoneNumber) {
        updateFields['phoneNumber'] = phone;
        debugPrint('📲 Phone changed → Will update');
      }

      if (user.status == AuthUserStatus.invited) {
        updateFields['status'] = 'active';
        debugPrint('🚀 Status is invited → Promoting to active');
      }

      debugPrint('🧪 Final updateFields: $updateFields');

      if (updateFields.isNotEmpty) {
        debugPrint('📤 Updating AuthUser → $updateFields');
        await authUserController.updateAuthUserFields(user.uid, updateFields);
      } else {
        debugPrint('🟡 No AuthUser fields changed — skipping update');
      }

      // ─────────────────────────────────────────────
      // 🔄 Force session rehydration
      // ─────────────────────────────────────────────
      debugPrint('🔄 Reloading UserSessionController...');
      await sessionController.reload(forceRefresh: true);

      // 🌀 Refresh CombinedUser + AuthUser
      ref.invalidate(combinedUserProvider);
      ref.invalidate(authUserControllerProvider);

      final updatedCombinedUser = await ref.read(combinedUserProvider.future);
      final updatedUser = sessionController.currentUser;

      if (updatedUser == null) {
        debugPrint('❌ AuthUser still null after reload — aborting navigation.');
        throw Exception('No AuthUser after session reload');
      }

      _user = updatedCombinedUser ?? user;

      state = const AsyncData(null);
      SnackService.showSuccess('✅ Profile updated');

      // 🧭 Redirect if just activated
      if (user.status == AuthUserStatus.invited && context.mounted) {
        debugPrint('🔁 User was invited — routing back to root...');
        Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
      }

      return true;
    } catch (e, st) {
      debugPrint('❌ Profile submission failed: $e');
      debugPrintStack(stackTrace: st);
      state = AsyncError(e, st);
      SnackService.showError('❌ Failed to save profile: $e');
      return false;
    }
  }

  /// 🖼️ Update avatar
  Future<void> updateAvatar(String uid, String newUrl) =>
      _runFieldUpdate(uid, {'avatarUrl': newUrl}, 'Avatar');

  /// 👤 Update role
  Future<void> updateRole(String uid, String role) async {
    final tenantId = ref.read(tenantIdProvider);
    final controller = await ref.read(
      userProfileControllerProvider(tenantId).future,
    );
    try {
      await controller.updateUserRole(uid, role);
      SnackService.showSuccess('✅ Role updated');
    } catch (e) {
      SnackService.showError('❌ Failed to update role: $e');
    }
  }

  /// 🏪 Update assigned stores
  Future<void> updateStores(String uid, List<String> stores) async {
    final tenantId = ref.read(tenantIdProvider);
    final controller = await ref.read(
      userProfileControllerProvider(tenantId).future,
    );
    try {
      await controller.updateUserStores(uid, stores);
      SnackService.showSuccess('✅ Store access updated');
    } catch (e) {
      SnackService.showError('❌ Failed to update stores: $e');
    }
  }

  /// ❌ Remove a specific store
  Future<void> removeStore(
    String uid,
    List<String> currentStores,
    String storeId,
  ) {
    final updated = currentStores.where((id) => id != storeId).toList();
    return updateStores(uid, updated);
  }

  /// 🔁 Internal helper for updating single fields
  Future<void> _runFieldUpdate(
    String uid,
    Map<String, dynamic> fields,
    String label,
  ) async {
    final tenantId = ref.read(tenantIdProvider);
    final controller = await ref.read(
      userProfileControllerProvider(tenantId).future,
    );
    try {
      await controller.updateUserProfile(uid, fields);
      SnackService.showSuccess('✅ $label updated');
    } catch (e) {
      SnackService.showError('❌ Failed to update $label: $e');
    }
  }
}
