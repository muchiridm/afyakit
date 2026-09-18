// lib/hq/users/all_users/controllers/all_users_controller_memberships.dart

part of 'all_users_controller.dart';

mixin AllUsersMembershipActions on StateNotifier<AllUsersState> {
  Future<AllUsersService> _ensureSvc();

  List<AllUserMembership> membershipsForUser(AllUser user) {
    final cached = state.membershipsByUid[user.id];

    if (cached != null && cached.isNotEmpty) {
      return cached.values.toList()
        ..sort((a, b) => a.tenantId.compareTo(b.tenantId));
    }

    return user.memberships;
  }

  Future<Map<String, AllUserMembership>> fetchMemberships(String uid) async {
    if (!mounted) return const {};

    final u = uid.trim();
    if (u.isEmpty) return const {};

    final cached = state.membershipsByUid[u];
    if (cached != null) return cached;

    return _refreshMemberships(u, showError: true);
  }

  Future<Map<String, AllUserMembership>> _refreshMemberships(
    String uid, {
    bool showError = false,
  }) async {
    if (!mounted) return const {};

    final u = uid.trim();
    if (u.isEmpty) return const {};

    try {
      final svc = await _ensureSvc();
      if (!mounted) return const {};

      final map = await svc.fetchUserMemberships(u);
      if (!mounted) return const {};

      final next = Map<String, Map<String, AllUserMembership>>.from(
        state.membershipsByUid,
      );
      next[u] = map;

      state = state.copyWith(membershipsByUid: next);

      _patchUserMemberships(uid: u, memberships: map.values.toList());

      return map;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('🧨 _refreshMemberships failed uid=$u: $e\n$st');
      }

      if (showError) {
        SnackService.showError('❌ Failed to load memberships: $e');
      }

      return const {};
    }
  }

  Future<void> refreshMembershipsForUid(String uid) async {
    final u = uid.trim();
    if (u.isEmpty) return;

    await _refreshMemberships(u, showError: true);
  }

  void _upsertDirectoryUser(AllUser user) {
    if (!mounted) return;

    final items = List<AllUser>.from(state.items);
    final idx = items.indexWhere((e) => e.id == user.id);

    if (idx >= 0) {
      items[idx] = user;
    } else {
      items.insert(0, user);
    }

    state = state.copyWith(items: items);
  }

  void _patchUserMemberships({
    required String uid,
    required List<AllUserMembership> memberships,
  }) {
    if (!mounted) return;

    final items = List<AllUser>.from(state.items);
    final idx = items.indexWhere((e) => e.id == uid);

    if (idx < 0) return;

    final current = items[idx];

    final tenantIds =
        memberships
            .map((m) => m.tenantId.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    items[idx] = AllUser(
      id: current.id,
      email: current.email,
      emailLower: current.emailLower,
      displayName: current.displayName,
      photoURL: current.photoURL,
      phoneNumber: current.phoneNumber,
      createdAt: current.createdAt,
      lastLoginAt: current.lastLoginAt,
      disabled: current.disabled,
      tenantIds: tenantIds,
      tenantCount: tenantIds.length,
      memberships: memberships,
      authExists: current.authExists,
    );

    state = state.copyWith(items: items);
  }

  AllUser? _userFromPatchResponse(Map<String, Object?> res) {
    final rawUser = res['user'];
    if (rawUser is! Map) return null;

    final m = Map<String, Object?>.from(rawUser.cast<String, Object?>());
    final id = (m['id'] ?? m['uid'])?.toString().trim() ?? '';

    if (id.isEmpty) return null;

    return AllUser.fromJson(id, m);
  }

  String? _uidFromPatchResponse(Map<String, Object?> res) {
    final rawUser = res['user'];

    if (rawUser is Map) {
      final uid = (rawUser['uid'] ?? rawUser['id'])?.toString().trim();
      if (uid != null && uid.isNotEmpty) return uid;
    }

    final uid = (res['uid'] ?? res['id'])?.toString().trim();
    if (uid != null && uid.isNotEmpty) return uid;

    return null;
  }
}
