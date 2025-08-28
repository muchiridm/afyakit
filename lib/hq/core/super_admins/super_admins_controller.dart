// lib/hq/users/super_admins/super_admins_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/api/api_client.dart';
import 'package:afyakit/api/api_routes.dart';
import 'package:afyakit/hq/core/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/hq/core/super_admins/super_admins_service.dart';
import 'package:afyakit/hq/core/super_admins/super_admin_model.dart';

import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/extensions/user_role_x.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:afyakit/shared/types/dtos.dart';
import 'package:afyakit/hq/controllers/hq_controller.dart';

final superAdminsControllerProvider =
    StateNotifierProvider.autoDispose<SuperAdminsController, SuperAdminsState>((
      ref,
    ) {
      final controller = SuperAdminsController(ref);

      // small keep-alive grace period
      final link = ref.keepAlive();
      Timer? cancelTimer;
      ref.onCancel(() {
        cancelTimer = Timer(const Duration(seconds: 10), link.close);
      });
      ref.onResume(() => cancelTimer?.cancel());

      return controller;
    });

// ─────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────
class SuperAdminsState {
  final bool isLoading;
  final List<SuperAdmin> items;
  final String? error;

  const SuperAdminsState({
    this.isLoading = false,
    this.items = const <SuperAdmin>[],
    this.error,
  });

  SuperAdminsState copyWith({
    bool? isLoading,
    List<SuperAdmin>? items,
    String? error, // pass '' to clear
  }) {
    return SuperAdminsState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      error: error == '' ? null : (error ?? this.error),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────────────────────
class SuperAdminsController extends StateNotifier<SuperAdminsState> {
  final Ref ref;
  SuperAdminsController(this.ref) : super(const SuperAdminsState());

  SuperAdminsService? _svc;
  Future<void> _ensureSvc() async {
    if (_svc != null) return;
    final client = await ref.read(apiClientProvider.future);
    final tenantId = ref.read(tenantIdProvider);
    _svc = SuperAdminsService(client: client, routes: ApiRoutes(tenantId));
  }

  // keep provider alive for long ops
  Future<T> _runWithKeepAlive<T>(Future<T> Function() op) async {
    final keep = ref.keepAlive();
    try {
      return await op();
    } finally {
      keep.close();
    }
  }

  // Optional: piggyback the global busy overlay
  Future<T> _withBusy<T>(
    BuildContext context,
    Future<T> Function() op, {
    String? success,
  }) {
    final hq = ref.read(hqControllerProvider.notifier);
    return hq.withBusy(context, op, success: success);
  }

  // ── Read superadmins ────────────────────────────────────────
  Future<void> load() => _runWithKeepAlive(() async {
    if (!mounted) return;
    final prevItems = mounted ? state.items : const <SuperAdmin>[];
    if (mounted) {
      state = SuperAdminsState(isLoading: true, items: prevItems, error: null);
    }

    try {
      await _ensureSvc();
      final list = await _svc!.listSuperAdmins();
      if (!mounted) return;
      state = state.copyWith(isLoading: false, items: list, error: '');
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
      SnackService.showError('❌ Failed to load super admins: $e');
    }
  });

  // ── Public UI flows (controller owns dialogs/snacks) ────────

  /// Opens a prompt (DialogService) to enter a UID and promotes it.
  Future<void> promoteViaPrompt(BuildContext context) async {
    final uid = await DialogService.prompt(
      context: context,
      title: 'Promote to Superadmin',
      confirmText: 'Promote',
    );
    if (uid == null) return;

    await _withBusy(
      context,
      () => _toggle(uid, true),
      success: 'Promoted to superadmin',
    );
  }

  /// Confirms demotion (DialogService) and performs it.
  Future<void> demoteWithConfirm(
    BuildContext context, {
    required String uid,
    String? label,
  }) async {
    final ok = await DialogService.confirm(
      context: context,
      title: 'Demote superadmin?',
      content:
          'Remove superadmin privileges for ${label ?? uid}? This can be re-enabled later.',
      confirmText: 'Demote',
      confirmColor: Colors.redAccent,
    );
    if (!ok) return;

    await _withBusy(
      context,
      () => _toggle(uid, false),
      success: 'Demoted from superadmin',
    );
  }

  // ── Core toggle (no UI) ─────────────────────────────────────
  Future<void> _toggle(String uid, bool value) => _runWithKeepAlive(() async {
    try {
      await _ensureSvc();

      // (Optional) tiny optimistic UX for DEMOTE: remove the row immediately.
      if (!value && mounted) {
        state = state.copyWith(
          items: state.items.where((u) => u.uid != uid).toList(),
        );
      }

      await _svc!.setSuperAdmin(uid: uid, value: value);

      // If your UI is still powered by the Firestore stream, keep this:
      // ref.invalidate(superAdminsStreamSortedProvider);

      // Always reconcile from source of truth
      await load();

      SnackService.showSuccess(value ? '✅ Promoted' : '✅ Demoted');
    } catch (e, st) {
      if (kDebugMode) debugPrint('🧨 super admin toggle threw: $e\n$st');
      // Roll back any optimistic removal by reloading
      await load();
      SnackService.showError('❌ Update failed: $e');
      rethrow;
    }
  });

  // ─────────────────────────────────────────────────────────────
  // HQ cross-tenant actions (left intact; controller already owns snacks)
  // ─────────────────────────────────────────────────────────────

  Future<List<AuthUser>> listUsersForTenant(
    String tenantId, {
    String? search,
    int limit = 50,
    bool silent = false,
  }) => _runWithKeepAlive(() async {
    try {
      await _ensureSvc();
      final users = await _svc!.listUsersForTenant(
        tenantId: tenantId,
        search: search,
        limit: limit,
      );
      if (kDebugMode) {
        debugPrint(
          '👥 [SuperAdminsController] Loaded ${users.length} users '
          'for tenant=$tenantId (search="${search ?? ''}", limit=$limit)',
        );
      }
      return users;
    } catch (e, st) {
      if (kDebugMode) debugPrint('🧨 listUsersForTenant threw: $e\n$st');
      if (!silent) {
        SnackService.showError('❌ Failed to load users for $tenantId: $e');
      }
      return const <AuthUser>[];
    }
  });

  Future<InviteResult?> inviteUserForTenant({
    required String targetTenantId,
    String? email,
    String? phoneNumber,
    String role = 'staff',
    String? brandBaseUrl,
    bool forceResend = false,
  }) => _runWithKeepAlive(() async {
    final cleanedEmail = (email ?? '').trim();
    final cleanedPhone = (phoneNumber ?? '').trim();

    if (cleanedEmail.isEmpty && cleanedPhone.isEmpty) {
      SnackService.showError('Please enter an email or phone number.');
      return null;
    }
    if (cleanedEmail.isNotEmpty && !cleanedEmail.contains('@')) {
      SnackService.showError('Please enter a valid email.');
      return null;
    }

    try {
      await _ensureSvc();
      final res = await _svc!.inviteUserForTenant(
        targetTenantId: targetTenantId,
        email: cleanedEmail.isEmpty ? null : cleanedEmail,
        phoneNumber: cleanedPhone.isEmpty ? null : cleanedPhone,
        role: _parseRole(role),
        brandBaseUrl: brandBaseUrl,
        forceResend: forceResend,
      );
      SnackService.showSuccess('✅ Invite sent for tenant $targetTenantId');
      return res;
    } catch (e) {
      SnackService.showError('❌ HQ invite failed: $e');
      return null;
    }
  });

  Future<void> deleteUserFromTenant({
    required String targetTenantId,
    required String uid,
    String? label,
  }) => _runWithKeepAlive(() async {
    try {
      await _ensureSvc();
      await _svc!.deleteUserForTenant(targetTenantId, uid);
      SnackService.showSuccess(
        '🗑️ Removed from $targetTenantId${label != null ? ' ($label)' : ''}',
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('🧨 deleteUserFromTenant threw: $e\n$st');
      SnackService.showError('❌ HQ delete failed: $e');
    }
  });

  // ── helpers ─────────────────────────────────────────────────
  UserRole _parseRole(String? r) {
    if (r == null || r.trim().isEmpty) return UserRole.staff;
    switch (r.trim().toLowerCase()) {
      case 'owner':
        return UserRole.owner;
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'client':
        return UserRole.client;
      case 'staff':
      default:
        return UserRole.staff;
    }
  }
}
