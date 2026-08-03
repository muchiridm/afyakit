// lib/hq/users/all_users/controllers/all_users_controller.dart

import 'dart:async';

import 'package:afyakit/core/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/core/hq/users/all_users/all_users_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'all_users_state.dart';
part 'all_users_controller_memberships.dart';
part 'all_users_controller_actions.dart';

final allUsersControllerProvider =
    StateNotifierProvider.autoDispose<AllUsersController, AllUsersState>(
      (ref) => AllUsersController(ref),
    );

class AllUsersController extends StateNotifier<AllUsersState>
    with AllUsersMembershipActions, AllUsersTenantAccessActions {
  AllUsersController(this.ref) : super(const AllUsersState());

  final Ref ref;

  AllUsersService? _svc;
  Timer? _debounce;

  @override
  Future<AllUsersService> _ensureSvc() async {
    if (_svc != null) return _svc!;

    final created = await ref.read(allUsersServiceProvider.future);
    _svc = created;

    return created;
  }

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
      if (kDebugMode) debugPrint('🧨 AllUsers.load failed: $e\n$st');
      if (!mounted) return;

      state = state.copyWith(loading: false, error: e.toString());

      SnackService.showError('❌ Failed to load users: $e');
    }
  }

  bool _hasNoTenantAccess(AllUser user) {
    final hasEmbeddedMemberships = user.memberships.any(
      (m) => m.tenantId.trim().isNotEmpty,
    );

    final hasTenantIds = user.tenantIds.any((id) => id.trim().isNotEmpty);

    return !hasEmbeddedMemberships && !hasTenantIds;
  }

  void setSearch(String q) {
    if (!mounted) return;

    final v = q.trim();
    state = state.copyWith(search: v);

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      // ignore: discarded_futures
      load();
    });
  }

  void setLimit(int limit) {
    if (!mounted) return;

    final safe = limit.clamp(1, 500);
    state = state.copyWith(limit: safe);

    // ignore: discarded_futures
    load();
  }

  Future<void> refresh() => load();

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
  /// null/empty = all users.
  /// non-empty = tenant filter.
  void setTargetTenant(String? tenantId) {
    final clean = tenantId?.trim();

    if (clean == null || clean.isEmpty) {
      setUserFilter(mode: AllUsersFilterMode.all);
      return;
    }

    setUserFilter(mode: AllUsersFilterMode.tenant, tenantId: clean);
  }

  String? get targetTenantId => state.targetTenantId;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
