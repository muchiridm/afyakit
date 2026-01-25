import 'package:flutter/foundation.dart';

import '../../shared/models/zoho_account.dart';

@immutable
class ZohoAccountsState {
  const ZohoAccountsState({
    this.loading = false,
    this.refreshing = false,
    this.error,
    this.search,
    this.typeFilter,
    this.activeFilter,
    this.accounts = const <ZohoAccount>[],
  });

  final bool loading;
  final bool refreshing;
  final String? error;

  final String? search; // local filter/query param
  final String? typeFilter; // e.g. "cash", "bank"
  final bool? activeFilter; // true/false/null

  final List<ZohoAccount> accounts;

  bool get busy => loading || refreshing;

  ZohoAccountsState copyWith({
    bool? loading,
    bool? refreshing,
    String? error,
    bool clearError = false,
    String? search,
    bool clearSearch = false,
    String? typeFilter,
    bool clearTypeFilter = false,
    bool? activeFilter,
    bool clearActiveFilter = false,
    List<ZohoAccount>? accounts,
    bool clearAccounts = false,
  }) {
    return ZohoAccountsState(
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : (error ?? this.error),
      search: clearSearch ? null : (search ?? this.search),
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      activeFilter: clearActiveFilter
          ? null
          : (activeFilter ?? this.activeFilter),
      accounts: clearAccounts
          ? const <ZohoAccount>[]
          : (accounts ?? this.accounts),
    );
  }
}
