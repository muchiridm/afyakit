// 📁 features/user_profiles/controllers/profile_editor_controller.dart (updated)

import 'package:afyakit/users/providers/user_engine_providers.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/utils/normalize/normalize_phone.dart';
import 'package:afyakit/shared/services/snack_service.dart';

import 'package:afyakit/users/models/combined_user_model.dart';
import 'package:afyakit/users/extensions/auth_user_status_enum.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/users/providers/combined_user_provider.dart';
import 'package:afyakit/users/providers/combined_users_provider.dart';

// ✅ new imports: engine + provider + result
import 'package:afyakit/users/engines/profile_engine.dart';
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/users/controllers/session_controller.dart';

// ─────────────────────────────────────────────────────────────
// 🔧 Controller with optional UID (for invite flows)
// ─────────────────────────────────────────────────────────────
final profileControllerProvider =
    StateNotifierProvider.family<ProfileController, AsyncValue<void>, String?>(
      (ref, inviteUid) => ProfileController(ref, inviteUid: inviteUid),
    );

// ─────────────────────────────────────────────────────────────
// 🔍 Lookup a user by UID from live stream (fixed implementation)
// ─────────────────────────────────────────────────────────────
final combinedUserByIdProvider = Provider.family<CombinedUser?, String>((
  ref,
  uid,
) {
  final allUsers = ref.watch(combinedUsersProvider);
  return allUsers.firstWhereOrNull((u) => u.uid == uid);
});

class ProfileController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  final String? inviteUid;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  CombinedUser? _user;
  bool _initialized = false;

  ProfileEngine? _engine; // lazy, cached

  CombinedUser? get user => _user;

  ProfileController(this.ref, {this.inviteUid}) : super(const AsyncData(null)) {
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

  Future<void> _ensureEngine() async {
    if (_engine != null) return;
    final tenantId = ref.read(tenantIdProvider);
    _engine = await ref.read(profileEngineProvider(tenantId).future);
  }

  /// 🔄 Save profile changes to backend (via ProfileEngine)
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
      await _ensureEngine();
      final sessionCtrl = ref.read(
        sessionControllerProvider(ref.read(tenantIdProvider)).notifier,
      );

      // 1) 👤 Update UserProfile (displayName/avatar/role)
      final profilePayload = {
        'displayName': name,
        'avatarUrl': user.avatarUrl ?? '',
        'role': user.role.name,
      };
      debugPrint('📦 Updating UserProfile → $profilePayload');
      final r1 = await _engine!.updateProfile(user.uid, profilePayload);
      if (r1 is Err<void>) {
        state = AsyncError(r1.error, StackTrace.current);
        SnackService.showError('❌ Failed to save profile: ${r1.error.message}');
        return false;
      }

      // 2) 🔄 Prepare AuthUser updates (promote invited, update phone)
      final needsPhoneUpdate = phone != user.phoneNumber;
      final needsPromotion = user.status == AuthUserStatus.invited;

      if (needsPhoneUpdate || needsPromotion) {
        final r2 = await _engine!.promoteInviteAndPatchAuth(
          user.uid,
          phoneNumber: needsPhoneUpdate ? phone : null,
        );
        if (r2 is Err<void>) {
          state = AsyncError(r2.error, StackTrace.current);
          SnackService.showError(
            '❌ Failed to update account: ${r2.error.message}',
          );
          return false;
        }
      } else {
        debugPrint('🟡 No AuthUser fields changed — skipping auth update');
      }

      // 3) 🔁 Force session rehydration
      debugPrint('🔄 Reloading SessionController...');
      await sessionCtrl.reload(forceRefresh: true);

      // 4) 🌀 Refresh CombinedUser cache
      ref.invalidate(combinedUserProvider);
      final updatedCombinedUser = await ref.read(combinedUserProvider.future);
      final updatedUser = sessionCtrl.currentUser;

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

  /// 🖼️ Update avatar (profile-only field)
  Future<void> updateAvatar(String uid, String newUrl) =>
      _runFieldUpdate(uid, {'avatarUrl': newUrl}, 'Avatar');

  /// 👤 Update role
  Future<void> updateRole(String uid, String role) async {
    await _ensureEngine();
    try {
      final res = await _engine!.updateRole(uid, role);
      if (res is Err<void>) {
        SnackService.showError('❌ Failed to update role: ${res.error.message}');
        return;
      }
      SnackService.showSuccess('✅ Role updated');
    } catch (e) {
      SnackService.showError('❌ Failed to update role: $e');
    }
  }

  /// 🏪 Update assigned stores
  Future<void> updateStores(String uid, List<String> stores) async {
    await _ensureEngine();
    try {
      final res = await _engine!.updateStores(uid, stores);
      if (res is Err<void>) {
        SnackService.showError(
          '❌ Failed to update stores: ${res.error.message}',
        );
        return;
      }
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

  /// 🔁 Internal helper for updating single profile fields
  Future<void> _runFieldUpdate(
    String uid,
    Map<String, dynamic> fields,
    String label,
  ) async {
    await _ensureEngine();
    try {
      final res = await _engine!.updateProfile(uid, fields);
      if (res is Err<void>) {
        SnackService.showError(
          '❌ Failed to update $label: ${res.error.message}',
        );
        return;
      }
      SnackService.showSuccess('✅ $label updated');
    } catch (e) {
      SnackService.showError('❌ Failed to update $label: $e');
    }
  }
}
