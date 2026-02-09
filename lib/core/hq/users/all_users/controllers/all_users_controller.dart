// lib/hq/users/all_users/all_users_controller.dart

import 'dart:async';

import 'package:afyakit/core/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/core/hq/users/all_users/all_users_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final allUsersControllerProvider =
    StateNotifierProvider.autoDispose<AllUsersController, AllUsersState>(
      (ref) => AllUsersController(ref),
    );

class AllUsersState {
  final bool loading;
  final String? error;

  /// Directory search (global user directory)
  final String search;

  /// HQ target tenant slug for tenant access edits.
  /// When null => only directory list is active.
  final String? targetTenantId;

  final int limit;

  /// Directory (global) users list
  final List<AllUser> items;

  /// uid → { tenantId → { role, active, email? } }
  final Map<String, Map<String, Map<String, Object?>>> membershipsByUid;

  const AllUsersState({
    this.loading = false,
    this.error,
    this.search = '',
    this.targetTenantId,
    this.limit = 50,
    this.items = const <AllUser>[],
    this.membershipsByUid = const {},
  });

  AllUsersState copyWith({
    bool? loading,
    String? error, // pass '' to clear
    String? search,
    String? targetTenantId,
    int? limit,
    List<AllUser>? items,
    Map<String, Map<String, Map<String, Object?>>>? membershipsByUid,
  }) {
    return AllUsersState(
      loading: loading ?? this.loading,
      error: (error == '') ? null : (error ?? this.error),
      search: search ?? this.search,
      targetTenantId: targetTenantId ?? this.targetTenantId,
      limit: limit ?? this.limit,
      items: items ?? this.items,
      membershipsByUid: membershipsByUid ?? this.membershipsByUid,
    );
  }
}

class AllUsersController extends StateNotifier<AllUsersState> {
  AllUsersController(this.ref) : super(const AllUsersState());

  final Ref ref;
  AllUsersService? _svc;
  Timer? _debounce;

  Future<AllUsersService> _ensureSvc() async {
    if (_svc != null) return _svc!;
    final created = await ref.read(allUsersServiceProvider.future);
    _svc = created;
    return created;
  }

  // ─────────────────────────────────────────────
  // Directory: loading / listing (READ-ONLY)
  // ─────────────────────────────────────────────

  Future<void> load({String? search, int? limit}) async {
    if (!mounted) return;

    state = state.copyWith(
      loading: true,
      search: search ?? state.search,
      limit: limit ?? state.limit,
      error: '',
    );

    try {
      final svc = await _ensureSvc();
      if (!mounted) return;

      final list = await svc.fetchAllUsers(
        tenantId: null,
        search: state.search,
        limit: state.limit,
      );
      if (!mounted) return;

      state = state.copyWith(loading: false, items: list, error: '');

      // background hydration of directory memberships cache
      _hydrateMissingMemberships(list);
    } catch (e, st) {
      if (kDebugMode) debugPrint('🧨 AllUsers.load failed: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(loading: false, error: e.toString());
      SnackService.showError('❌ Failed to load users: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Search / limit (with debounce)
  // ─────────────────────────────────────────────

  void setSearch(String q) {
    if (!mounted) return;
    final v = q.trim();
    state = state.copyWith(search: v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => load());
  }

  void setLimit(int limit) {
    if (!mounted) return;
    final safe = limit.clamp(1, 500);
    state = state.copyWith(limit: safe);
    // ignore: discarded_futures
    load();
  }

  Future<void> refresh() => load();

  // ─────────────────────────────────────────────
  // HQ target tenant (what you edit access against)
  // ─────────────────────────────────────────────

  void setTargetTenant(String? tenantId) {
    if (!mounted) return;
    final v = (tenantId?.trim().isEmpty ?? true) ? null : tenantId!.trim();
    state = state.copyWith(targetTenantId: v);
  }

  String? get targetTenantId => state.targetTenantId;

  // ─────────────────────────────────────────────
  // Directory memberships (READ-ONLY cache)
  // ─────────────────────────────────────────────

  Future<Map<String, Map<String, Object?>>> fetchMemberships(String uid) async {
    if (!mounted) return const {};

    final cached = state.membershipsByUid[uid];
    if (cached != null) return cached;

    try {
      final svc = await _ensureSvc();
      if (!mounted) return const {};

      final map = await svc.fetchUserMemberships(uid);
      if (!mounted) return const {};

      final next = Map<String, Map<String, Map<String, Object?>>>.from(
        state.membershipsByUid,
      );
      next[uid] = map;

      state = state.copyWith(membershipsByUid: next);
      return map;
    } catch (e) {
      SnackService.showError('❌ Failed to load memberships: $e');
      return const {};
    }
  }

  Future<void> _refreshMemberships(String uid) async {
    try {
      final svc = await _ensureSvc();
      if (!mounted) return;

      final map = await svc.fetchUserMemberships(uid);
      if (!mounted) return;

      final next = Map<String, Map<String, Map<String, Object?>>>.from(
        state.membershipsByUid,
      );
      next[uid] = map;
      state = state.copyWith(membershipsByUid: next);
    } catch (_) {
      // swallow
    }
  }

  // ─────────────────────────────────────────────
  // Helpers: keep directory list fresh
  // ─────────────────────────────────────────────

  void _upsertDirectoryUser(AllUser user) {
    final items = List<AllUser>.from(state.items);
    final idx = items.indexWhere((e) => e.id == user.id);
    if (idx >= 0) {
      items[idx] = user;
    } else {
      items.insert(0, user);
    }
    state = state.copyWith(items: items);
  }

  AllUser? _userFromPatchResponse(Map<String, Object?> res) {
    final rawUser = res['user'];
    if (rawUser is! Map) return null;

    final m = Map<String, Object?>.from(rawUser.cast<String, Object?>());
    final id = (m['id'] ?? m['uid'])?.toString().trim() ?? '';
    if (id.isEmpty) return null;

    return AllUser.fromJson(id, m);
  }

  // ─────────────────────────────────────────────
  // HQ Tenant auth_users: CREATE via HQ
  // ─────────────────────────────────────────────

  /// POST /api/tenants/:slug/auth_users
  /// Returns created/ensured uid (global identity).
  Future<String?> hqCreateTenantUser({
    required String targetTenantId,
    required String phoneNumber,
    String? displayName,
  }) async {
    if (!mounted) return null;

    final t = targetTenantId.trim();
    final phone = phoneNumber.trim();
    final dn = displayName?.trim();

    if (t.isEmpty) {
      SnackService.showError('Pick a target tenant first');
      return null;
    }
    if (phone.isEmpty) {
      SnackService.showError('Phone number is required');
      return null;
    }

    try {
      final svc = await _ensureSvc();
      if (!mounted) return null;

      final res = await svc.hqCreateTenantUser(
        targetTenantId: t,
        phoneNumber: phone,
        displayName: (dn == null || dn.isEmpty) ? null : dn,
      );

      final created = _userFromPatchResponse(res);
      if (created != null) {
        _upsertDirectoryUser(created);
      }

      final uid =
          created?.id ??
          ((res['user'] is Map)
              ? ((res['user'] as Map)['uid'] ?? (res['user'] as Map)['id'])
                    ?.toString()
                    .trim()
              : null);

      if (uid == null || uid.isEmpty) {
        SnackService.showError('Create succeeded but uid missing in response');
        return null;
      }

      // Mark membership cache optimistic, then refresh real values.
      final current = Map<String, Map<String, Map<String, Object?>>>.from(
        state.membershipsByUid,
      );
      final userMems = Map<String, Map<String, Object?>>.from(
        current[uid] ?? {},
      );
      userMems[t] = <String, Object?>{
        'role': userMems[t]?['role'] ?? '—',
        'active': true,
      };
      current[uid] = userMems;
      state = state.copyWith(membershipsByUid: current);

      // ignore: discarded_futures
      _refreshMemberships(uid);

      SnackService.showSuccess('✅ User added to $t');
      return uid;
    } catch (e, st) {
      if (kDebugMode) debugPrint('🧨 hqCreateTenantUser failed: $e\n$st');
      SnackService.showError('❌ Failed to create tenant user: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // HQ Tenant auth_users: PATCH (aligned to BE)
  // ─────────────────────────────────────────────

  Map<String, Object?> _cleanPatch(Map<String, Object?> patch) {
    // Intentionally keep:
    // - null values (backend supports nullable fields)
    // - empty lists (staffRoles: [] is how we revoke staff)
    final out = <String, Object?>{};
    patch.forEach((k, v) {
      if (k.trim().isEmpty) return;
      out[k] = v;
    });
    return out;
  }

  Future<Map<String, Object?>?> hqPatchTenantUser({
    required String targetTenantId,
    required String uid,
    required Map<String, Object?> patch,
  }) async {
    if (!mounted) return null;

    final t = targetTenantId.trim();
    final u = uid.trim();
    if (t.isEmpty) {
      SnackService.showError('❌ Missing target tenant');
      return null;
    }
    if (u.isEmpty) {
      SnackService.showError('❌ Missing user uid');
      return null;
    }

    final payload = _cleanPatch(patch);
    if (payload.isEmpty) {
      SnackService.showError('❌ Nothing to update');
      return null;
    }

    try {
      final svc = await _ensureSvc();
      final res = await svc.hqPatchTenantUser(
        targetTenantId: t,
        uid: u,
        patch: payload,
      );

      final updated = _userFromPatchResponse(res);
      if (updated != null) {
        _upsertDirectoryUser(updated);
      }

      // Refresh memberships cache so UI reflects role changes immediately
      // ignore: discarded_futures
      _refreshMemberships(u);

      SnackService.showSuccess('✅ Saved');
      return res;
    } catch (e, st) {
      if (kDebugMode) debugPrint('🧨 hqPatchTenantUser failed: $e\n$st');
      SnackService.showError('❌ Failed to save: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // 🔥 Convenience ops aligned to BE schema
  // ─────────────────────────────────────────────

  Future<void> setTenantUserStatus({
    required String targetTenantId,
    required String uid,
    required String status, // 'active' | 'disabled'
  }) async {
    await hqPatchTenantUser(
      targetTenantId: targetTenantId,
      uid: uid,
      patch: <String, Object?>{'status': status},
    );
  }

  Future<void> setTenantUserStores({
    required String targetTenantId,
    required String uid,
    required List<String> stores,
  }) async {
    await hqPatchTenantUser(
      targetTenantId: targetTenantId,
      uid: uid,
      patch: <String, Object?>{'stores': stores},
    );
  }

  Future<void> updateTenantUserProfile({
    required String targetTenantId,
    required String uid,
    String? displayName,
    String? firstName,
    String? lastName,
    bool? isCompany,
    String? companyName,
    String? avatarUrl,
  }) async {
    final patch = <String, Object?>{};

    if (displayName != null) patch['displayName'] = displayName;
    if (firstName != null) patch['firstName'] = firstName;
    if (lastName != null) patch['lastName'] = lastName;

    if (isCompany != null) patch['isCompany'] = isCompany;
    if (companyName != null) patch['companyName'] = companyName;

    if (avatarUrl != null) patch['avatarUrl'] = avatarUrl;

    await hqPatchTenantUser(
      targetTenantId: targetTenantId,
      uid: uid,
      patch: patch,
    );
  }

  /// Make them staff with roles.
  /// Backend expects: type: 'staff' and staffRoles: [...]
  Future<void> grantStaff({
    required String targetTenantId,
    required String uid,
    required List<String> staffRoles,
  }) async {
    await hqPatchTenantUser(
      targetTenantId: targetTenantId,
      uid: uid,
      patch: <String, Object?>{'type': 'staff', 'staffRoles': staffRoles},
    );
  }

  /// ✅ Revoke staff explicitly:
  /// staffRoles: [] AND type: 'member'
  Future<void> revokeStaff({
    required String targetTenantId,
    required String uid,
  }) async {
    await hqPatchTenantUser(
      targetTenantId: targetTenantId,
      uid: uid,
      patch: const <String, Object?>{
        'type': 'member',
        'staffRoles': <String>[],
      },
    );
  }

  // ─────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────

  Future<void> hqDeleteTenantUser({
    required String targetTenantId,
    required String uid,
  }) async {
    if (!mounted) return;

    final t = targetTenantId.trim();
    final u = uid.trim();
    if (t.isEmpty || u.isEmpty) return;

    try {
      final svc = await _ensureSvc();
      await svc.hqDeleteTenantUser(targetTenantId: t, uid: u);

      final current = Map<String, Map<String, Map<String, Object?>>>.from(
        state.membershipsByUid,
      );
      final userMems = Map<String, Map<String, Object?>>.from(current[u] ?? {});
      userMems.remove(t);
      current[u] = userMems;

      if (mounted) state = state.copyWith(membershipsByUid: current);

      SnackService.showSuccess('🗑️ Removed tenant access');
    } catch (e, st) {
      if (kDebugMode) debugPrint('🧨 hqDeleteTenantUser failed: $e\n$st');
      SnackService.showError('❌ Failed to remove access: $e');
    }
  }

  /// Force refresh memberships from backend and update cache.
  Future<void> refreshMembershipsForUid(String uid) async {
    if (!mounted) return;
    final u = uid.trim();
    if (u.isEmpty) return;
    await _refreshMemberships(u);
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  void _hydrateMissingMemberships(List<AllUser> items) {
    // ignore: discarded_futures
    () async {
      for (final u in items) {
        if (!mounted) return;

        final cached = state.membershipsByUid[u.id];
        if (cached != null && cached.isNotEmpty) continue;

        try {
          await fetchMemberships(u.id);
        } catch (_) {
          // swallow
        }
      }
    }();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
