import 'dart:async';

import 'package:afyakit/features/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/features/hq/users/all_users/all_users_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Keep the provider next to the controller
final allUsersControllerProvider =
    StateNotifierProvider.autoDispose<AllUsersController, AllUsersState>(
      (ref) => AllUsersController(ref),
    );

class AllUsersState {
  final bool loading;
  final String? error;
  final String search;
  final String? tenantFilter; // optional filter by tenantId
  final int limit;
  final List<AllUser> items;
  // uid → { tenantId → { role, active, email? } }
  final Map<String, Map<String, Map<String, Object?>>> membershipsByUid;

  const AllUsersState({
    this.loading = false,
    this.error,
    this.search = '',
    this.tenantFilter,
    this.limit = 50,
    this.items = const <AllUser>[],
    this.membershipsByUid = const {},
  });

  AllUsersState copyWith({
    bool? loading,
    String? error, // pass '' to clear
    String? search,
    String? tenantFilter,
    int? limit,
    List<AllUser>? items,
    Map<String, Map<String, Map<String, Object?>>>? membershipsByUid,
  }) {
    return AllUsersState(
      loading: loading ?? this.loading,
      error: (error == '') ? null : (error ?? this.error),
      search: search ?? this.search,
      tenantFilter: tenantFilter ?? this.tenantFilter,
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
    // _ensureSvc is only called from methods that already check `mounted`
    final created = await ref.read(allUsersServiceProvider.future);
    _svc = created;
    return created;
  }

  // ─────────────────────────────────────────────
  // Loading / listing
  // ─────────────────────────────────────────────

  Future<void> load({String? search, String? tenantId, int? limit}) async {
    if (!mounted) return;

    state = state.copyWith(
      loading: true,
      search: search ?? state.search,
      tenantFilter: tenantId ?? state.tenantFilter,
      limit: limit ?? state.limit,
      error: '',
    );

    try {
      final svc = await _ensureSvc();
      if (!mounted) return;

      final list = await svc.fetchAllUsers(
        tenantId: state.tenantFilter,
        search: state.search,
        limit: state.limit,
      );
      if (!mounted) return;

      state = state.copyWith(loading: false, items: list, error: '');

      // Fire-and-forget background hydration of memberships (per-tenant email, role, active)
      _hydrateMissingMemberships(list);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('🧨 AllUsers.load failed: $e\n$st');
      }
      if (!mounted) return;
      state = state.copyWith(loading: false, error: e.toString());
      SnackService.showError('❌ Failed to load users: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Search / filter / limit (with debounce)
  // ─────────────────────────────────────────────

  void setSearch(String q) {
    if (!mounted) return;
    final v = q.trim();
    state = state.copyWith(search: v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => load());
  }

  void setTenantFilter(String? tenantId) {
    if (!mounted) return;
    final v = (tenantId?.trim().isEmpty ?? true) ? null : tenantId!.trim();
    state = state.copyWith(tenantFilter: v);
    // fire-and-forget; load() itself checks mounted
    // ignore: discarded_futures
    load();
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
  // Global directory CRUD
  // ─────────────────────────────────────────────

  Future<AllUser?> createUser({
    required String phoneNumber,
    String? displayName,
  }) async {
    if (!mounted) return null;

    try {
      final svc = await _ensureSvc();
      if (!mounted) return null;

      final created = await svc.createGlobalUser(
        phoneNumber: phoneNumber,
        displayName: displayName,
      );
      if (!mounted) return created;

      final items = <AllUser>[created, ...state.items];
      state = state.copyWith(items: items);

      SnackService.showInfo('✅ User created');
      return created;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('🧨 AllUsers.createUser failed: $e\n$st');
      }
      SnackService.showError('❌ Failed to create user: $e');
      return null;
    }
  }

  Future<AllUser?> updateUser({
    required String uid,
    String? phoneNumber,
    String? displayName,
    bool? disabled,
  }) async {
    if (!mounted) return null;

    try {
      final svc = await _ensureSvc();
      if (!mounted) return null;

      final updated = await svc.updateGlobalUser(
        uid: uid,
        phoneNumber: phoneNumber,
        displayName: displayName,
        disabled: disabled,
      );
      if (!mounted) return updated;

      final items = state.items
          .map((u) => u.id == updated.id ? updated : u)
          .toList(growable: false);

      state = state.copyWith(items: items);

      SnackService.showInfo('✅ User updated');
      return updated;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('🧨 AllUsers.updateUser failed: $e\n$st');
      }
      SnackService.showError('❌ Failed to update user: $e');
      return null;
    }
  }

  Future<void> deleteUser(String uid) async {
    if (!mounted) return;

    try {
      final svc = await _ensureSvc();
      if (!mounted) return;

      await svc.deleteGlobalUser(uid);
      if (!mounted) return;

      final items = state.items
          .where((u) => u.id != uid)
          .toList(growable: false);

      final mems = Map<String, Map<String, Map<String, Object?>>>.from(
        state.membershipsByUid,
      )..remove(uid);

      state = state.copyWith(items: items, membershipsByUid: mems);

      SnackService.showInfo('✅ User deleted');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('🧨 AllUsers.deleteUser failed: $e\n$st');
      }
      SnackService.showError('❌ Failed to delete user: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Memberships (with cache)
  // ─────────────────────────────────────────────

  Future<Map<String, Map<String, Object?>>> fetchMemberships(String uid) async {
    if (!mounted) return const {};

    // Safe to read state now; if we get disposed later, we bail before any writes.
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
      // If we got here because the controller was disposed mid-flight,
      // the next `fetchMemberships` will just no-op and return {}.
      SnackService.showError('❌ Failed to load memberships: $e');
      return const {};
    }
  }

  Future<void> updateMembership(
    String uid,
    String tenantId, {
    required String role,
    required bool active,
    String? email,
  }) async {
    if (!mounted) return;

    try {
      final svc = await _ensureSvc();
      if (!mounted) return;

      await svc.upsertUserMembership(
        uid: uid,
        tenantId: tenantId,
        role: role,
        active: active,
        email: email,
      );
      if (!mounted) return;

      final current = Map<String, Map<String, Map<String, Object?>>>.from(
        state.membershipsByUid,
      );
      final userMems = Map<String, Map<String, Object?>>.from(
        current[uid] ?? {},
      );

      final patch = <String, Object?>{'role': role, 'active': active};
      if (email != null) {
        patch['email'] = email;
      }

      userMems[tenantId] = patch;
      current[uid] = userMems;

      state = state.copyWith(membershipsByUid: current);

      SnackService.showInfo('✅ Membership updated');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('🧨 AllUsers.updateMembership failed: $e\n$st');
      }
      SnackService.showError('❌ Failed to update membership');
    }
  }

  Future<void> removeMembership(String uid, String tenantId) async {
    if (!mounted) return;

    try {
      final svc = await _ensureSvc();
      if (!mounted) return;

      await svc.deleteUserMembership(uid: uid, tenantId: tenantId);
      if (!mounted) return;

      final current = Map<String, Map<String, Map<String, Object?>>>.from(
        state.membershipsByUid,
      );
      final userMems = Map<String, Map<String, Object?>>.from(
        current[uid] ?? {},
      );
      userMems.remove(tenantId);
      current[uid] = userMems;

      state = state.copyWith(membershipsByUid: current);

      SnackService.showInfo('✅ Membership removed');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('🧨 AllUsers.removeMembership failed: $e\n$st');
      }
      SnackService.showError('❌ Failed to remove membership');
    }
  }

  // ─────────────────────────────────────────────
  // Background hydrator for memberships
  // ─────────────────────────────────────────────

  void _hydrateMissingMemberships(List<AllUser> items) {
    // fire-and-forget; errors are already surfaced inside fetchMemberships
    // ignore: discarded_futures
    () async {
      for (final u in items) {
        if (!mounted) return;

        // Only skip if we *already* have memberships cached for this uid.
        final cached = state.membershipsByUid[u.id];
        if (cached != null && cached.isNotEmpty) {
          continue;
        }

        try {
          await fetchMemberships(u.id);
        } catch (_) {
          // swallow; SnackService already handled it
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
