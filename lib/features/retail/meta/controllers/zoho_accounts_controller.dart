// lib/features/retail/zoho/accounts/controllers/zoho_accounts_controller.dart

import 'package:afyakit/features/retail/shared/models/zoho_account.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../services/zoho_meta_service.dart';

final zohoAccountsControllerProvider =
    StateNotifierProvider<ZohoAccountsController, ZohoAccountsState>(
      (ref) => ZohoAccountsController(ref),
    );

class ZohoAccountsController extends StateNotifier<ZohoAccountsState> {
  ZohoAccountsController(this._ref) : super(const ZohoAccountsState());

  final Ref _ref;

  bool get _busy => state.busy;

  Future<List<ZohoAccount>> _fetchAccounts() async {
    final svc = await _ref.read(zohoMetaServiceProvider.future);
    final search = (state.search ?? '').trim();
    final type = (state.typeFilter ?? '').trim();

    return svc.listAccounts(
      search: search.isEmpty ? null : search,
      type: type.isEmpty ? null : type,
      active: state.activeFilter,
    );
  }

  Future<void> load({bool force = false}) async {
    // Prevent a second request while a first request is in flight.
    if (_busy) return;

    state = state.copyWith(
      loading: true,
      clearError: true,
      clearAccounts: true,
      notConfigured: false,
    );

    try {
      final items = await _fetchAccounts();
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        accounts: items,
        notConfigured: false,
        clearError: true,
      );
    } catch (error) {
      if (!mounted) return;
      final missingConfiguration = _isZohoNotConfigured(error);
      state = state.copyWith(
        loading: false,
        notConfigured: missingConfiguration,
        error: missingConfiguration ? null : _errorMessage(error),
        clearError: missingConfiguration,
      );
    }
  }

  Future<void> refresh() async {
    if (_busy) return;

    state = state.copyWith(refreshing: true, clearError: true);

    try {
      final items = await _fetchAccounts();
      if (!mounted) return;
      state = state.copyWith(
        refreshing: false,
        accounts: items,
        notConfigured: false,
        clearError: true,
      );
    } catch (error) {
      if (!mounted) return;
      final missingConfiguration = _isZohoNotConfigured(error);
      state = state.copyWith(
        refreshing: false,
        notConfigured: missingConfiguration,
        error: missingConfiguration ? null : _errorMessage(error),
        clearError: missingConfiguration,
      );
    }
  }

  void setSearch(String? value) {
    if (_busy) return;
    final trimmed = (value ?? '').trim();
    state = state.copyWith(
      search: trimmed.isEmpty ? null : trimmed,
      clearSearch: trimmed.isEmpty,
      clearError: true,
    );
  }

  void setTypeFilter(String? value) {
    if (_busy) return;
    final trimmed = (value ?? '').trim();
    state = state.copyWith(
      typeFilter: trimmed.isEmpty ? null : trimmed,
      clearTypeFilter: trimmed.isEmpty,
      clearError: true,
    );
  }

  void setActiveFilter(bool? value) {
    if (_busy) return;
    state = state.copyWith(
      activeFilter: value,
      clearActiveFilter: value == null,
      clearError: true,
    );
  }

  void clearFilters() {
    if (_busy) return;
    state = state.copyWith(
      clearSearch: true,
      clearTypeFilter: true,
      clearActiveFilter: true,
      clearError: true,
    );
  }

  static bool _isZohoNotConfigured(Object error) {
    if (error is! DioException) return false;
    final response = error.response;
    if (response?.statusCode != 404) return false;

    final data = response?.data;
    if (data is! Map) return false;

    final message = (data['error'] ?? '').toString().trim().toLowerCase();
    return message.contains('zoho books is not configured');
  }

  static String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final serverMessage = (data['error'] ?? data['message'] ?? '')
            .toString()
            .trim();
        if (serverMessage.isNotEmpty) return serverMessage;
      }
      if (error.response?.statusCode == 401) {
        return 'Your session has expired. Please sign in again.';
      }
      if (error.response?.statusCode == 403) {
        return 'You do not have permission to view Zoho accounts.';
      }
      return 'Unable to load Zoho accounts. Please try again.';
    }
    return 'Unable to load Zoho accounts. Please try again.';
  }
}

@immutable
class ZohoAccountsState {
  const ZohoAccountsState({
    this.loading = false,
    this.refreshing = false,
    this.notConfigured = false,
    this.error,
    this.search,
    this.typeFilter,
    this.activeFilter,
    this.accounts = const <ZohoAccount>[],
  });

  final bool loading;
  final bool refreshing;
  final bool notConfigured;
  final String? error;

  final String? search;
  final String? typeFilter;
  final bool? activeFilter;
  final List<ZohoAccount> accounts;

  bool get busy => loading || refreshing;

  ZohoAccountsState copyWith({
    bool? loading,
    bool? refreshing,
    bool? notConfigured,
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
      notConfigured: notConfigured ?? this.notConfigured,
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
