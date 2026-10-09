// lib/features/hq/users/all_users/controllers/all_users_controller.dart

import 'dart:async';

import 'package:afyakit/features/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/features/hq/users/all_users/all_users_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'all_users_controller_memberships.dart';
part 'all_users_controller_actions.dart';

// ─────────────────────────────────────────────
// Filters
// ─────────────────────────────────────────────

enum AllUsersFilterMode { all, noTenant, tenant }

// ─────────────────────────────────────────────
// State
// ─────────────────────────────────────────────

@immutable
class AllUsersState {
  /// Whether the directory is loading.
  final bool loading;

  /// Most recent directory error.
  final String? error;

  /// Directory search query.
  final String search;

  /// Selected tenant for tenant-filtered mode.
  ///
  /// Null when displaying all users or users
  /// without tenant access.
  final String? targetTenantId;

  /// Current user-list filter.
  final AllUsersFilterMode filterMode;

  /// Maximum number of users to retrieve.
  final int limit;

  /// Directory users.
  ///
  /// Memberships should be embedded in each AllUser
  /// returned by the backend.
  final List<AllUser> items;

  /// Detail/fallback membership cache.
  ///
  /// UID -> tenantId -> membership.
  ///
  /// Application-specific memberships and roles
  /// are contained within AllUserMembership:
  ///
  /// - appMembershipsByApp
  /// - staffRolesByApp
  ///
  /// Do not hydrate this cache for every directory row.
  /// The directory should normally use embedded
  /// AllUser.memberships.
  final Map<String, Map<String, AllUserMembership>> membershipsByUid;

  const AllUsersState({
    this.loading = false,
    this.error,
    this.search = '',
    this.targetTenantId,
    this.filterMode = AllUsersFilterMode.all,
    this.limit = 50,
    this.items = const <AllUser>[],
    this.membershipsByUid = const {},
  });

  AllUsersState copyWith({
    bool? loading,
    String? error,
    String? search,
    String? targetTenantId,
    bool targetTenantIdSet = false,
    AllUsersFilterMode? filterMode,
    int? limit,
    List<AllUser>? items,
    Map<String, Map<String, AllUserMembership>>? membershipsByUid,
  }) {
    return AllUsersState(
      loading: loading ?? this.loading,
      error: error == '' ? null : (error ?? this.error),
      search: search ?? this.search,
      targetTenantId: targetTenantIdSet ? targetTenantId : this.targetTenantId,
      filterMode: filterMode ?? this.filterMode,
      limit: limit ?? this.limit,
      items: items ?? this.items,
      membershipsByUid: membershipsByUid ?? this.membershipsByUid,
    );
  }
}

// ─────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────

final allUsersControllerProvider =
    StateNotifierProvider.autoDispose<AllUsersController, AllUsersState>(
      (ref) => AllUsersController(ref),
    );

// ─────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────

class AllUsersController extends StateNotifier<AllUsersState>
    with AllUsersMembershipActions, AllUsersTenantAccessActions {
  AllUsersController(this.ref) : super(const AllUsersState());

  final Ref ref;

  AllUsersService? _svc;
  Timer? _debounce;

  // ───────────────────────────────────────────
  // Service
  // ───────────────────────────────────────────

  @override
  Future<AllUsersService> _ensureSvc() async {
    if (_svc != null) {
      return _svc!;
    }

    final created = await ref.read(allUsersServiceProvider.future);

    _svc = created;

    return created;
  }

  // ───────────────────────────────────────────
  // Directory loading
  // ───────────────────────────────────────────

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

      final selectedTenantId = state.targetTenantId?.trim();

      final backendTenantFilter =
          state.filterMode == AllUsersFilterMode.tenant &&
              selectedTenantId != null &&
              selectedTenantId.isNotEmpty
          ? selectedTenantId
          : null;

      final rawList = await svc.fetchAllUsers(
        tenantId: backendTenantFilter,
        search: state.search,
        limit: state.filterMode == AllUsersFilterMode.noTenant
            ? 500
            : state.limit,
      );

      final list = state.filterMode == AllUsersFilterMode.noTenant
          ? rawList.where(_hasNoTenantAccess).take(state.limit).toList()
          : rawList;

      if (!mounted) return;

      state = state.copyWith(loading: false, items: list, error: '');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('🧨 AllUsers.load failed: $e\n$st');
      }

      if (!mounted) return;

      state = state.copyWith(loading: false, error: e.toString());

      SnackService.showError('❌ Failed to load users: $e');
    }
  }

  // ───────────────────────────────────────────
  // Membership filtering
  // ───────────────────────────────────────────

  bool _hasNoTenantAccess(AllUser user) {
    final hasEmbeddedMemberships = user.memberships.any(
      (membership) => membership.tenantId.trim().isNotEmpty,
    );

    final hasTenantIds = user.tenantIds.any(
      (tenantId) => tenantId.trim().isNotEmpty,
    );

    return !hasEmbeddedMemberships && !hasTenantIds;
  }

  // ───────────────────────────────────────────
  // Search
  // ───────────────────────────────────────────

  void setSearch(String query) {
    if (!mounted) return;

    final value = query.trim();

    state = state.copyWith(search: value);

    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      // ignore: discarded_futures
      load();
    });
  }

  // ───────────────────────────────────────────
  // Pagination
  // ───────────────────────────────────────────

  void setLimit(int limit) {
    if (!mounted) return;

    final safe = limit.clamp(1, 500);

    state = state.copyWith(limit: safe);

    // ignore: discarded_futures
    load();
  }

  // ───────────────────────────────────────────
  // Refresh
  // ───────────────────────────────────────────

  Future<void> refresh() => load();

  // ───────────────────────────────────────────
  // Tenant filtering
  // ───────────────────────────────────────────

  void setUserFilter({required AllUsersFilterMode mode, String? tenantId}) {
    if (!mounted) return;

    final cleanTenantId = (tenantId?.trim().isEmpty ?? true)
        ? null
        : tenantId!.trim();

    final nextTenantId = mode == AllUsersFilterMode.tenant
        ? cleanTenantId
        : null;

    final safeMode = mode == AllUsersFilterMode.tenant && nextTenantId == null
        ? AllUsersFilterMode.all
        : mode;

    if (safeMode == state.filterMode && nextTenantId == state.targetTenantId) {
      return;
    }

    state = state.copyWith(
      filterMode: safeMode,
      targetTenantId: nextTenantId,
      targetTenantIdSet: true,
      membershipsByUid: const {},
      error: '',
    );

    // ignore: discarded_futures
    load();
  }

  /// Compatibility method for older callers.
  ///
  /// Null/empty -> all users.
  /// Non-empty -> users belonging to one tenant.
  void setTargetTenant(String? tenantId) {
    final clean = tenantId?.trim();

    if (clean == null || clean.isEmpty) {
      setUserFilter(mode: AllUsersFilterMode.all);
      return;
    }

    setUserFilter(mode: AllUsersFilterMode.tenant, tenantId: clean);
  }

  String? get targetTenantId => state.targetTenantId;

  // ───────────────────────────────────────────
  // Lifecycle
  // ───────────────────────────────────────────

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
