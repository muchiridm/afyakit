// 📂 lib/users/controllers/auth_user_controller.dart

import 'dart:async';
import 'package:afyakit/users/user_manager/extensions/user_role_x.dart';
import 'package:afyakit/users/user_manager/models/super_admim_model.dart';
import 'package:afyakit/users/user_manager/providers/user_engine_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';

import 'package:afyakit/users/user_manager/models/auth_user_model.dart';
import 'package:afyakit/users/user_manager/models/global_user_model.dart';
import 'package:afyakit/users/utils/parse_user_role.dart';

import 'package:afyakit/users/user_manager/engines/user_manager_engine.dart';
import 'package:afyakit/shared/types/result.dart';

final userManagerControllerProvider =
    StateNotifierProvider.autoDispose<UserManagerController, AuthUserState>(
      (ref) => UserManagerController(ref),
    );

// ─────────────────────────────────────────────────────────────
// 🧠 State (now also holds global directory filters)
// ─────────────────────────────────────────────────────────────
class AuthUserState {
  // form state
  final String email;
  final UserRole role;
  final Set<String> selectedStoreIds;
  final bool isLoading;

  // global directory filters (migrated from GlobalUserController)
  final String tenantFilter; // '', 'afyakit', 'danabtmc', 'dawapap'
  final String search;
  final int limit;

  const AuthUserState({
    // form defaults
    this.email = '',
    this.role = UserRole.staff,
    this.selectedStoreIds = const {},
    this.isLoading = false,
    // global directory defaults
    this.tenantFilter = '',
    this.search = '',
    this.limit = 50,
  });

  AuthUserState copyWith({
    // form
    String? email,
    UserRole? role,
    Set<String>? selectedStoreIds,
    bool? isLoading,
    // global directory
    String? tenantFilter,
    String? search,
    int? limit,
  }) {
    return AuthUserState(
      email: email ?? this.email,
      role: role ?? this.role,
      selectedStoreIds: selectedStoreIds ?? this.selectedStoreIds,
      isLoading: isLoading ?? this.isLoading,
      tenantFilter: tenantFilter ?? this.tenantFilter,
      search: search ?? this.search,
      limit: limit ?? this.limit,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 🎛️ Controller
// ─────────────────────────────────────────────────────────────
class UserManagerController extends StateNotifier<AuthUserState> {
  final Ref ref;
  UserManagerController(this.ref) : super(const AuthUserState());

  // Engine
  UserManagerEngine? _engine;
  Future<void> _ensureEngine() async {
    if (_engine != null) return;
    final tenantId = ref.read(tenantIdProvider);
    _engine = await ref.read(userManagerEngineProvider(tenantId).future);
  }

  // ─────────────────────────────────────────────────────────────
  // UI form setters (tenant user ops)
  // ─────────────────────────────────────────────────────────────
  void setEmail(String email) => state = state.copyWith(email: email);

  void setFormRole(UserRole role) => state = state.copyWith(role: role);

  void setFormRoleFromString(String roleStr) =>
      state = state.copyWith(role: parseUserRole(roleStr));

  void toggleStore(String storeId) {
    final updated = {...state.selectedStoreIds};
    updated.contains(storeId) ? updated.remove(storeId) : updated.add(storeId);
    state = state.copyWith(selectedStoreIds: updated);
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
      state = const AuthUserState(); // reset form + filters to defaults
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

  // ─────────────────────────────────────────────────────────────
  // 👥 Read tenant-scoped users
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
  // 🗑️ Delete user (tenant membership)
  // ─────────────────────────────────────────────────────────────
  Future<void> deleteUser(String uid) async {
    try {
      await _ensureEngine();
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

  // ======================================================================
  // 🌍 GLOBAL DIRECTORY (replaces GlobalUserController)
  // ======================================================================

  // expose getters to mirror the old controller’s API
  String get tenantFilter => state.tenantFilter;
  String get search => state.search;
  int get limit => state.limit;

  set tenantFilter(String v) {
    if (state.tenantFilter == v) return;
    state = state.copyWith(tenantFilter: v);
    _notifyAndRefreshGlobalUsers(immediate: true);
  }

  set globalSearch(String v) {
    if (state.search == v) return;
    state = state.copyWith(search: v);
    _notifyAndRefreshGlobalUsers(); // debounced
  }

  set globalLimit(int v) {
    if (state.limit == v) return;
    state = state.copyWith(limit: v);
    _notifyAndRefreshGlobalUsers(immediate: true);
  }

  final _globalUsersCtrl = StreamController<List<GlobalUser>>.broadcast();
  Timer? _globalUsersPoll;
  Timer? _debounce;
  Duration _pollEvery = const Duration(seconds: 8);

  Stream<List<GlobalUser>> get globalUsersStream => _globalUsersCtrl.stream;

  void startGlobalUsersStream({Duration? every}) {
    _pollEvery = every ?? _pollEvery;
    _startPolling();
  }

  void stopGlobalUsersStream() {
    _globalUsersPoll?.cancel();
    _globalUsersPoll = null;
  }

  Future<void> refreshGlobalUsersOnce() => _emitGlobalUsersOnce();

  Future<Map<String, Map<String, Object?>>> memberships(String uid) async {
    try {
      await _ensureEngine();
      final res = await _engine!.hqMemberships(uid);
      if (res is Ok<Map<String, Map<String, Object?>>>) return res.value;
      if (res is Err<Map<String, Map<String, Object?>>>) {
        debugPrint('❌ memberships failed: ${res.error.message}');
      }
      return <String, Map<String, Object?>>{};
    } catch (e) {
      debugPrint('❌ memberships exception: $e');
      return <String, Map<String, Object?>>{};
    }
  }

  void _startPolling() {
    _globalUsersPoll?.cancel();
    _emitGlobalUsersOnce();
    _globalUsersPoll = Timer.periodic(
      _pollEvery,
      (_) => _emitGlobalUsersOnce(),
    );
  }

  Future<void> _emitGlobalUsersOnce() async {
    try {
      await _ensureEngine();
      final res = await _engine!.hqUsers(
        tenantId: state.tenantFilter.isEmpty ? null : state.tenantFilter,
        search: state.search,
        limit: state.limit,
      );
      if (res is Ok<List<GlobalUser>>) {
        _globalUsersCtrl.add(res.value);
      } else if (res is Err<List<GlobalUser>>) {
        debugPrint('❌ global users fetch failed: ${res.error.message}');
      }
    } catch (e) {
      debugPrint('❌ global users fetch exception: $e');
    }
  }

  void _notifyAndRefreshGlobalUsers({bool immediate = false}) {
    // No notifyListeners on StateNotifier. State has already been updated above.
    // We just debounce a refresh for the stream consumers.
    _debounce?.cancel();
    _debounce = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 300),
      () {
        if (_globalUsersPoll == null) {
          _emitGlobalUsersOnce();
        }
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ⭐ Superadmins (HQ) – controller API for the UI
  // ─────────────────────────────────────────────────────────────
  Future<List<SuperAdmin>> listSuperAdmins() async {
    try {
      await _ensureEngine();
      final res = await _engine!.listSuperAdmins();
      if (res is Ok<List<SuperAdmin>>) return res.value;
      if (res is Err<List<SuperAdmin>>) {
        final msg = res.error.message;
        SnackService.showError('❌ Failed to load superadmins: $msg');
        throw Exception(msg); // so FutureBuilder shows the error
      }
      return <SuperAdmin>[]; // should not hit
    } catch (e) {
      SnackService.showError('❌ Failed to load superadmins: $e');
      rethrow;
    }
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

  @override
  void dispose() {
    _debounce?.cancel();
    _globalUsersPoll?.cancel();
    _globalUsersCtrl.close();
    super.dispose();
  }
}
