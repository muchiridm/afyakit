// lib/hq/users/all_users/all_users_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/hq/users/all_users/all_users_service.dart';

// Keep the provider next to the controller (as requested)
final allUsersControllerProvider =
    StateNotifierProvider.autoDispose<AllUsersController, AllUsersState>(
      (ref) => AllUsersController(ref),
    );

class AllUsersState {
  final bool loading;
  final String? error;
  final String search;
  final String? tenantFilter; // optional filter
  final int limit;
  final List<AllUser> items;
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

  Future<AllUsersService> _ensureSvc() async {
    if (_svc != null) return _svc!;
    final created = await ref.read(allUsersServiceProvider.future);
    _svc = created;
    return created;
  }

  Timer? _debounce;

  // ── loading ─────────────────────────────────────────────────
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

      // Fire-and-forget background hydration for legacy users whose
      // directory aggregates are empty.
      _hydrateMissingMemberships(list);
    } catch (e, st) {
      if (kDebugMode) debugPrint('🧨 AllUsers.load failed: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(loading: false, error: e.toString());
      SnackService.showError('❌ Failed to load users: $e');
    }
  }

  // ── search/filter/limit (controller owns debounce) ──────────
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

  // ── memberships (with cache) ─────────────────────────────────
  Future<Map<String, Map<String, Object?>>> fetchMemberships(String uid) async {
    // cached
    final cached = state.membershipsByUid[uid];
    if (cached != null) return cached;

    try {
      final svc = await _ensureSvc();
      final map = await svc.fetchUserMemberships(uid);

      // write-through cache
      final next = Map<String, Map<String, Map<String, Object?>>>.from(
        state.membershipsByUid,
      );
      next[uid] = map;
      if (mounted) state = state.copyWith(membershipsByUid: next);
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
  }) async {
    try {
      final svc = await _ensureSvc();
      await svc.upsertUserMembership(
        uid: uid,
        tenantId: tenantId,
        role: role,
        active: active,
      );

      // Update local cache
      final current = Map<String, Map<String, Map<String, Object?>>>.from(
        state.membershipsByUid,
      );
      final userMems = Map<String, Map<String, Object?>>.from(
        current[uid] ?? {},
      );
      userMems[tenantId] = {'role': role, 'active': active};
      current[uid] = userMems;

      if (mounted) {
        state = state.copyWith(membershipsByUid: current);
      }

      SnackService.showInfo('✅ Membership updated');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('🧨 AllUsers.updateMembership failed: $e\n$st');
      }
      SnackService.showError('❌ Failed to update membership: $e');
    }
  }

  /// Remove a membership completely for a user on a tenant.
  Future<void> removeMembership(String uid, String tenantId) async {
    try {
      final svc = await _ensureSvc();
      await svc.deleteUserMembership(uid: uid, tenantId: tenantId);

      // Update local cache
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
      SnackService.showError('❌ Failed to remove membership: $e');
    }
  }

  /// HQ-level invite: creates/ensures Firebase Auth user and membership.
  Future<void> inviteUser({required String email, required String role}) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      SnackService.showError('❌ Email is required');
      return;
    }

    try {
      final svc = await _ensureSvc();
      await svc.inviteUser(email: trimmed, role: role);

      SnackService.showInfo('✅ Invite sent to $trimmed');
      // Optionally refresh the list so the new user shows up
      await refresh();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('🧨 AllUsers.inviteUser failed: $e\n$st');
      }
      SnackService.showError('❌ Failed to invite user: $e');
    }
  }

  // ── background hydrator for legacy users ─────────────────────
  void _hydrateMissingMemberships(List<AllUser> items) {
    // fire-and-forget; errors are already surfaced inside fetchMemberships
    // ignore: discarded_futures
    () async {
      for (final u in items) {
        if (!mounted) return;

        final hasAggregates = u.tenantIds.isNotEmpty || (u.tenantCount > 0);

        final cached = state.membershipsByUid[u.id];

        // Skip users that already have some membership signal
        if (hasAggregates || (cached != null && cached.isNotEmpty)) {
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
