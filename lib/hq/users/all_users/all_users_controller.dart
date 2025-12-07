import 'dart:async';

import 'package:afyakit/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/hq/users/all_users/all_users_service.dart';
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
    final v = q.trim();
    state = state.copyWith(search: v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => load());
  }

  void setTenantFilter(String? tenantId) {
    final v = (tenantId?.trim().isEmpty ?? true) ? null : tenantId!.trim();
    state = state.copyWith(tenantFilter: v);
    load();
  }

  void setLimit(int limit) {
    final safe = limit.clamp(1, 500);
    state = state.copyWith(limit: safe);
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
    try {
      final svc = await _ensureSvc();
      final created = await svc.createGlobalUser(
        phoneNumber: phoneNumber,
        displayName: displayName,
      );

      final items = <AllUser>[created, ...state.items];
      if (mounted) {
        state = state.copyWith(items: items);
      }

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
    try {
      final svc = await _ensureSvc();
      final updated = await svc.updateGlobalUser(
        uid: uid,
        phoneNumber: phoneNumber,
        displayName: displayName,
        disabled: disabled,
      );

      final items = state.items
          .map((u) => u.id == updated.id ? updated : u)
          .toList(growable: false);

      if (mounted) {
        state = state.copyWith(items: items);
      }

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
    try {
      final svc = await _ensureSvc();
      await svc.deleteGlobalUser(uid);

      final items = state.items
          .where((u) => u.id != uid)
          .toList(growable: false);

      final mems = Map<String, Map<String, Map<String, Object?>>>.from(
        state.membershipsByUid,
      )..remove(uid);

      if (mounted) {
        state = state.copyWith(items: items, membershipsByUid: mems);
      }

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
    final cached = state.membershipsByUid[uid];
    if (cached != null) return cached;

    try {
      final svc = await _ensureSvc();
      final map = await svc.fetchUserMemberships(uid);

      final next = Map<String, Map<String, Map<String, Object?>>>.from(
        state.membershipsByUid,
      );
      next[uid] = map;
      if (mounted) {
        state = state.copyWith(membershipsByUid: next);
      }
      return map;
    } catch (e) {
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
    try {
      final svc = await _ensureSvc();
      await svc.upsertUserMembership(
        uid: uid,
        tenantId: tenantId,
        role: role,
        active: active,
        email: email,
      );

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

      if (mounted) {
        state = state.copyWith(membershipsByUid: current);
      }

      SnackService.showInfo('✅ Membership updated');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('🧨 AllUsers.updateMembership failed: $e\n$st');
      }
      SnackService.showError('❌ Failed to update membership');
    }
  }

  Future<void> removeMembership(String uid, String tenantId) async {
    try {
      final svc = await _ensureSvc();
      await svc.deleteUserMembership(uid: uid, tenantId: tenantId);

      final current = Map<String, Map<String, Map<String, Object?>>>.from(
        state.membershipsByUid,
      );
      final userMems = Map<String, Map<String, Object?>>.from(
        current[uid] ?? {},
      );
      userMems.remove(tenantId);
      current[uid] = userMems;

      if (mounted) {
        state = state.copyWith(membershipsByUid: current);
      }

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
