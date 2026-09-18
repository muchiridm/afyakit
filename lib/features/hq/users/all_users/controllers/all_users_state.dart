// lib/hq/users/all_users/controllers/all_users_state.dart

part of 'all_users_controller.dart';

enum AllUsersFilterMode { all, noTenant, tenant }

class AllUsersState {
  final bool loading;
  final String? error;

  /// Directory search.
  final String search;

  /// Selected tenant for tenant-filtered mode.
  ///
  /// null when filterMode is all or noTenant.
  final String? targetTenantId;

  /// Current user list mode.
  final AllUsersFilterMode filterMode;

  final int limit;

  /// Directory users list.
  ///
  /// Memberships should be embedded in each [AllUser] from `/api/users`.
  final List<AllUser> items;

  /// Detail/fallback cache only.
  ///
  /// Do NOT hydrate this for every row in the users table.
  /// Normal list display should use [AllUser.memberships].
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
    String? error, // pass '' to clear
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
      error: (error == '') ? null : (error ?? this.error),
      search: search ?? this.search,
      targetTenantId: targetTenantIdSet ? targetTenantId : this.targetTenantId,
      filterMode: filterMode ?? this.filterMode,
      limit: limit ?? this.limit,
      items: items ?? this.items,
      membershipsByUid: membershipsByUid ?? this.membershipsByUid,
    );
  }
}
