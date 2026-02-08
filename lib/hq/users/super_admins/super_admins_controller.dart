// lib/hq/users/super_admins/super_admins_controller.dart

import 'dart:async';

import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';

import 'package:afyakit/hq/users/super_admins/super_admins_service.dart';
import 'package:afyakit/hq/users/super_admins/super_admin_model.dart';

import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:afyakit/hq/base/shell/hq_controller.dart';

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
// Controller (single responsibility: superadmins only)
// ─────────────────────────────────────────────────────────────
class SuperAdminsController extends StateNotifier<SuperAdminsState> {
  final Ref ref;
  SuperAdminsController(this.ref) : super(const SuperAdminsState());

  SuperAdminsService? _svc;

  Future<void> _ensureSvc() async {
    if (_svc != null) return;
    final tenantId = ref.read(tenantSlugProvider);
    final client = await ref.read(afyakitClientFutureProvider.future);
    _svc = SuperAdminsService(dio: client.dio, routes: AfyaKitRoutes(tenantId));
  }

  Future<T> _runWithKeepAlive<T>(Future<T> Function() op) async {
    final keep = ref.keepAlive();
    try {
      return await op();
    } finally {
      keep.close();
    }
  }

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

    final prevItems = state.items;
    state = SuperAdminsState(isLoading: true, items: prevItems, error: null);

    try {
      await _ensureSvc();
      final list = await _svc!.listSuperAdmins();
      if (!mounted) return;
      state = state.copyWith(isLoading: false, items: list, error: '');
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
      SnackService.showError('❌ Failed to load super admins: $e');
    }
  });

  // ── UI flows ────────────────────────────────────────────────

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

  Future<void> demoteWithConfirm(
    BuildContext context, {
    required String uid,
    String? label,
  }) async {
    final who = label ?? uid;

    final ok = await DialogService.confirm(
      context: context,
      title: 'Demote superadmin?',
      content:
          'Remove superadmin privileges for $who? This can be re-enabled later.',
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

      // Optional optimistic UX for DEMOTE
      if (!value && mounted) {
        state = state.copyWith(
          items: state.items.where((u) => u.uid != uid).toList(),
        );
      }

      await _svc!.setSuperAdmin(uid: uid, value: value);

      // reconcile
      await load();

      SnackService.showSuccess(value ? '✅ Promoted' : '✅ Demoted');
    } catch (e, st) {
      if (kDebugMode) debugPrint('🧨 super admin toggle threw: $e\n$st');
      await load(); // rollback optimistic changes
      SnackService.showError('❌ Update failed: $e');
      rethrow;
    }
  });
}
