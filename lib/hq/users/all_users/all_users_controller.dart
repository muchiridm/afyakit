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

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
