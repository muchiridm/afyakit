import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/shared/providers/api_client_provider.dart';
import 'package:afyakit/shared/providers/tenant_provider.dart';
import 'package:afyakit/shared/providers/users/combined_user_stream_provider.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/services/dialog_service.dart';

import 'package:afyakit/users/services/auth_user_service.dart';
import 'package:afyakit/users/services/user_profile_service.dart';
import 'package:afyakit/users/controllers/login_controller.dart';
import 'package:afyakit/users/controllers/user_session_controller.dart';

final userDeletionControllerProvider =
    AutoDisposeAsyncNotifierProvider<UserDeletionController, void>(
      UserDeletionController.new,
    );

class UserDeletionController extends AutoDisposeAsyncNotifier<void> {
  late final String tenantId;
  late final AuthUserService authUserService;
  late final UserProfileService profileService;

  @override
  FutureOr<void> build() async {
    tenantId = ref.read(tenantIdProvider);
    final client = await ref.read(apiClientProvider.future);
    final routes = ApiRoutes(tenantId);

    authUserService = AuthUserService(client: client, routes: routes);
    profileService = UserProfileService(client: client, routes: routes);
  }

  bool _isSelf(String uid) {
    final currentUser = ref.read(userSessionControllerProvider(tenantId)).value;
    return uid == currentUser?.uid;
  }

  /// 🧨 Delete a user with confirmation, feedback, and self-handling
  Future<void> deleteUser(String uid, {String? email}) async {
    final confirmed = await DialogService.confirm(
      title: 'Delete User',
      content:
          'Are you sure you want to permanently delete ${email ?? 'this user'}?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );
    if (confirmed != true) return;

    state = const AsyncLoading();
    bool profileDeleted = false;
    bool authDeleted = false;

    try {
      debugPrint('[🧨UserDeletion] Deleting profile → $uid');
      await profileService.deleteProfile(uid);
      profileDeleted = true;
    } catch (e, st) {
      debugPrint('[🧨UserDeletion] ⚠️ Failed to delete profile → $e');
      debugPrintStack(stackTrace: st);
    }

    try {
      debugPrint('[🧨UserDeletion] Deleting auth user → $uid');
      await authUserService.deleteUser(uid);
      authDeleted = true;
    } catch (e, st) {
      debugPrint('[🧨UserDeletion] ⚠️ Failed to delete auth user → $e');
      debugPrintStack(stackTrace: st);
    }

    // Final outcome
    if (profileDeleted || authDeleted) {
      ref.invalidate(combinedUserStreamProvider);

      if (_isSelf(uid)) {
        await ref.read(loginControllerProvider.notifier).logout();
      }

      SnackService.showSuccess(
        '✅ User deleted${email != null ? ": $email" : ""}',
      );
      state = const AsyncData(null);
    } else {
      SnackService.showError('❌ Failed to delete user: nothing was removed');
      state = const AsyncData(null);
    }
  }

  /// 🚫 Silent deletion for internal use (no confirmation/snack)
  Future<void> deleteUserSilent(String uid) async {
    try {
      debugPrint('[🧨UserDeletion] 🔕 Silent delete: Profile → $uid');
      await profileService.deleteProfile(uid);
    } catch (e, st) {
      debugPrint('[🧨UserDeletion] ⚠️ Silent delete failed (profile) → $e');
      debugPrintStack(stackTrace: st);
    }

    try {
      debugPrint('[🧨UserDeletion] 🔕 Silent delete: Auth → $uid');
      await authUserService.deleteUser(uid);
    } catch (e, st) {
      debugPrint('[🧨UserDeletion] ⚠️ Silent delete failed (auth) → $e');
      debugPrintStack(stackTrace: st);
    }

    ref.invalidate(combinedUserStreamProvider);

    if (_isSelf(uid)) {
      await ref.read(loginControllerProvider.notifier).logout();
    }

    debugPrint('[🧨UserDeletion] ✅ Silent deletion complete: $uid');
  }
}
