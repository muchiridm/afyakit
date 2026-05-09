// lib/hq/users/all_users/controllers/all_users_controller_actions.dart

part of 'all_users_controller.dart';

mixin AllUsersTenantAccessActions
    on StateNotifier<AllUsersState>, AllUsersMembershipActions {
  Future<AllUsersService> _ensureSvc();

  Future<String?> hqCreateTenantUser({
    required String targetTenantId,
    required String phoneNumber,
    String? displayName,
  }) async {
    if (!mounted) return null;

    final t = targetTenantId.trim();
    final phone = phoneNumber.trim();
    final dn = displayName?.trim();

    if (t.isEmpty) {
      SnackService.showError('Pick a target tenant first');
      return null;
    }

    if (phone.isEmpty) {
      SnackService.showError('Phone number is required');
      return null;
    }

    try {
      final svc = await _ensureSvc();
      if (!mounted) return null;

      final res = await svc.hqCreateTenantUser(
        targetTenantId: t,
        phoneNumber: phone,
        displayName: (dn == null || dn.isEmpty) ? null : dn,
      );

      final created = _userFromPatchResponse(res);
      if (created != null) {
        _upsertDirectoryUser(created);
      }

      final uid = created?.id ?? _uidFromPatchResponse(res);

      if (uid == null || uid.isEmpty) {
        SnackService.showError('Create succeeded but uid missing in response');
        return null;
      }

      _optimisticallySetMembership(
        uid: uid,
        tenantId: t,
        role: 'client',
        active: true,
        status: 'active',
        email: created?.email,
      );

      // ignore: discarded_futures
      _refreshMemberships(uid);

      SnackService.showSuccess('✅ User added to $t');

      return uid;
    } catch (e, st) {
      if (kDebugMode) debugPrint('🧨 hqCreateTenantUser failed: $e\n$st');
      SnackService.showError('❌ Failed to create tenant user: $e');
      return null;
    }
  }

  void _optimisticallySetMembership({
    required String uid,
    required String tenantId,
    required String role,
    required bool active,
    String? status,
    String? email,
  }) {
    if (!mounted) return;

    final u = uid.trim();
    final t = tenantId.trim();

    if (u.isEmpty || t.isEmpty) return;

    final current = Map<String, Map<String, AllUserMembership>>.from(
      state.membershipsByUid,
    );

    final userMems = Map<String, AllUserMembership>.from(current[u] ?? {});

    userMems[t] = AllUserMembership(
      tenantId: t,
      role: role,
      active: active,
      status: status,
      email: email,
    );

    current[u] = userMems;

    state = state.copyWith(membershipsByUid: current);

    _patchUserMemberships(uid: u, memberships: userMems.values.toList());
  }

  Map<String, Object?> _cleanPatch(Map<String, Object?> patch) {
    final out = <String, Object?>{};

    patch.forEach((k, v) {
      if (k.trim().isEmpty) return;
      out[k] = v;
    });

    return out;
  }

  Future<Map<String, Object?>?> hqPatchTenantUser({
    required String targetTenantId,
    required String uid,
    required Map<String, Object?> patch,
  }) async {
    if (!mounted) return null;

    final t = targetTenantId.trim();
    final u = uid.trim();

    if (t.isEmpty) {
      SnackService.showError('❌ Missing target tenant');
      return null;
    }

    if (u.isEmpty) {
      SnackService.showError('❌ Missing user uid');
      return null;
    }

    final payload = _cleanPatch(patch);

    if (payload.isEmpty) {
      SnackService.showError('❌ Nothing to update');
      return null;
    }

    try {
      final svc = await _ensureSvc();

      final res = await svc.hqPatchTenantUser(
        targetTenantId: t,
        uid: u,
        patch: payload,
      );

      final updated = _userFromPatchResponse(res);
      if (updated != null) {
        _upsertDirectoryUser(updated);
      }

      // ignore: discarded_futures
      _refreshMemberships(u);

      SnackService.showSuccess('✅ Saved');

      return res;
    } catch (e, st) {
      if (kDebugMode) debugPrint('🧨 hqPatchTenantUser failed: $e\n$st');
      SnackService.showError('❌ Failed to save: $e');
      return null;
    }
  }

  Future<void> setTenantUserStatus({
    required String targetTenantId,
    required String uid,
    required String status,
  }) async {
    await hqPatchTenantUser(
      targetTenantId: targetTenantId,
      uid: uid,
      patch: <String, Object?>{'status': status},
    );
  }

  Future<void> setTenantUserStores({
    required String targetTenantId,
    required String uid,
    required List<String> stores,
  }) async {
    await hqPatchTenantUser(
      targetTenantId: targetTenantId,
      uid: uid,
      patch: <String, Object?>{'stores': stores},
    );
  }

  Future<void> updateTenantUserProfile({
    required String targetTenantId,
    required String uid,
    String? displayName,
    String? firstName,
    String? lastName,
    bool? isCompany,
    String? companyName,
    String? avatarUrl,
  }) async {
    final patch = <String, Object?>{};

    if (displayName != null) patch['displayName'] = displayName;
    if (firstName != null) patch['firstName'] = firstName;
    if (lastName != null) patch['lastName'] = lastName;

    if (isCompany != null) patch['isCompany'] = isCompany;
    if (companyName != null) patch['companyName'] = companyName;

    if (avatarUrl != null) patch['avatarUrl'] = avatarUrl;

    await hqPatchTenantUser(
      targetTenantId: targetTenantId,
      uid: uid,
      patch: patch,
    );
  }

  Future<void> grantStaff({
    required String targetTenantId,
    required String uid,
    required List<String> staffRoles,
  }) async {
    await hqPatchTenantUser(
      targetTenantId: targetTenantId,
      uid: uid,
      patch: <String, Object?>{'type': 'staff', 'staffRoles': staffRoles},
    );
  }

  Future<void> revokeStaff({
    required String targetTenantId,
    required String uid,
  }) async {
    await hqPatchTenantUser(
      targetTenantId: targetTenantId,
      uid: uid,
      patch: const <String, Object?>{
        'type': 'member',
        'staffRoles': <String>[],
      },
    );
  }

  Future<void> hqDeleteTenantUser({
    required String targetTenantId,
    required String uid,
  }) async {
    if (!mounted) return;

    final t = targetTenantId.trim();
    final u = uid.trim();

    if (t.isEmpty || u.isEmpty) return;

    try {
      final svc = await _ensureSvc();

      await svc.hqDeleteTenantUser(targetTenantId: t, uid: u);

      _removeMembershipFromUser(uid: u, tenantId: t);

      SnackService.showSuccess('🗑️ Removed tenant access');
    } catch (e, st) {
      if (kDebugMode) debugPrint('🧨 hqDeleteTenantUser failed: $e\n$st');
      SnackService.showError('❌ Failed to remove access: $e');
    }
  }

  void _removeMembershipFromUser({
    required String uid,
    required String tenantId,
  }) {
    if (!mounted) return;

    final u = uid.trim();
    final t = tenantId.trim();

    if (u.isEmpty || t.isEmpty) return;

    final current = Map<String, Map<String, AllUserMembership>>.from(
      state.membershipsByUid,
    );

    final userMems = Map<String, AllUserMembership>.from(current[u] ?? {});
    userMems.remove(t);
    current[u] = userMems;

    final items = List<AllUser>.from(state.items);
    final idx = items.indexWhere((e) => e.id == u);

    if (idx >= 0) {
      final existing = items[idx];

      final updatedMemberships = membershipsForUser(
        existing,
      ).where((m) => m.tenantId != t).toList();

      final tenantIds =
          updatedMemberships
              .map((m) => m.tenantId.trim())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      items[idx] = AllUser(
        id: existing.id,
        email: existing.email,
        emailLower: existing.emailLower,
        displayName: existing.displayName,
        photoURL: existing.photoURL,
        phoneNumber: existing.phoneNumber,
        createdAt: existing.createdAt,
        lastLoginAt: existing.lastLoginAt,
        disabled: existing.disabled,
        tenantIds: tenantIds,
        tenantCount: tenantIds.length,
        memberships: updatedMemberships,
        authExists: existing.authExists,
      );
    }

    state = state.copyWith(membershipsByUid: current, items: items);
  }

  Future<bool> hqDeleteGlobalUser(String uid) async {
    if (!mounted) return false;

    final cleanUid = uid.trim();

    if (cleanUid.isEmpty) {
      SnackService.showError('Missing user uid');
      return false;
    }

    try {
      final svc = await _ensureSvc();

      await svc.hqDeleteGlobalUser(cleanUid);

      final items = state.items.where((u) => u.id != cleanUid).toList();

      final memberships = Map<String, Map<String, AllUserMembership>>.from(
        state.membershipsByUid,
      )..remove(cleanUid);

      state = state.copyWith(items: items, membershipsByUid: memberships);

      SnackService.showSuccess('🗑️ Global user deleted');
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('🧨 hqDeleteGlobalUser failed: $e\n$st');
      }

      SnackService.showError('❌ Failed to delete global user: $e');
      return false;
    }
  }
}
