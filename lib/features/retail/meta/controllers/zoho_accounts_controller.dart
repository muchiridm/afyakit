import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/zoho_meta_service.dart';
import 'zoho_accounts_state.dart';

final zohoAccountsControllerProvider =
    StateNotifierProvider<ZohoAccountsController, ZohoAccountsState>(
      (ref) => ZohoAccountsController(ref),
    );

class ZohoAccountsController extends StateNotifier<ZohoAccountsState> {
  ZohoAccountsController(this._ref) : super(const ZohoAccountsState());

  final Ref _ref;

  bool get _busy => state.busy;

  Future<void> load({bool force = false}) async {
    if (_busy && !force) return;

    state = state.copyWith(
      loading: true,
      clearError: true,
      clearAccounts: true,
    );

    try {
      final svc = await _ref.read(zohoMetaServiceProvider.future);
      final items = await svc.listAccounts(
        search: (state.search ?? '').trim().isEmpty
            ? null
            : state.search!.trim(),
        type: (state.typeFilter ?? '').trim().isEmpty
            ? null
            : state.typeFilter!.trim(),
        active: state.activeFilter,
      );

      state = state.copyWith(loading: false, accounts: items);
    } catch (e) {
      state = state.copyWith(loading: false, error: _err(e));
    }
  }

  Future<void> refresh() async {
    if (_busy) return;

    state = state.copyWith(refreshing: true, clearError: true);

    try {
      final svc = await _ref.read(zohoMetaServiceProvider.future);
      final items = await svc.listAccounts(
        search: (state.search ?? '').trim().isEmpty
            ? null
            : state.search!.trim(),
        type: (state.typeFilter ?? '').trim().isEmpty
            ? null
            : state.typeFilter!.trim(),
        active: state.activeFilter,
      );

      state = state.copyWith(refreshing: false, accounts: items);
    } catch (e) {
      state = state.copyWith(refreshing: false, error: _err(e));
    }
  }

  void setSearch(String? v) {
    if (_busy) return;
    final t = (v ?? '').trim();
    state = state.copyWith(search: t.isEmpty ? null : t, clearError: true);
  }

  void setTypeFilter(String? v) {
    if (_busy) return;
    final t = (v ?? '').trim();
    state = state.copyWith(typeFilter: t.isEmpty ? null : t, clearError: true);
  }

  void setActiveFilter(bool? v) {
    if (_busy) return;
    state = state.copyWith(activeFilter: v, clearError: true);
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

  static String _err(Object e) {
    final s = e.toString().trim();
    return s.isEmpty ? 'Unknown error' : s;
  }
}
