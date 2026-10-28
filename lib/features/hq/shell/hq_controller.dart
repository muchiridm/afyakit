// lib/core/hq/shell/hq_controller.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';

final hqControllerProvider = StateNotifierProvider<HqController, HqState>(
  (ref) => HqController(ref),
);

/// HQ tenant id (single truth)
const String hqTenantId = 'hq';

/// Top-right label
final hqCurrentEmailProvider = Provider<String?>(
  (_) => fb.FirebaseAuth.instance.currentUser?.email,
);

/// Persisted target tenant selection across tabs.
final hqTargetTenantIdProvider = Provider<String?>(
  (ref) => ref.watch(hqControllerProvider).targetTenantId,
);

enum HqAccountAction { refreshClaims, signOut }

@immutable
class HqState {
  final int tabIndex;
  final String userSearch;
  final bool busy;
  final String? banner;
  final String? targetTenantId;

  const HqState({
    this.tabIndex = 0,
    this.userSearch = '',
    this.busy = false,
    this.banner,
    this.targetTenantId,
  });

  HqState copyWith({
    int? tabIndex,
    String? userSearch,
    bool? busy,
    String? banner, // '' clears
    String? targetTenantId,
    bool targetTenantIdSet = false,
  }) {
    return HqState(
      tabIndex: tabIndex ?? this.tabIndex,
      userSearch: userSearch ?? this.userSearch,
      busy: busy ?? this.busy,
      banner: banner == '' ? null : (banner ?? this.banner),
      targetTenantId: targetTenantIdSet ? targetTenantId : this.targetTenantId,
    );
  }
}

class HqController extends StateNotifier<HqState> {
  HqController(this.ref) : super(const HqState());
  final Ref ref;

  // ── Navigation + search
  void setTab(int index) => state = state.copyWith(tabIndex: index);
  void setUserSearch(String q) => state = state.copyWith(userSearch: q.trim());

  // ── Target tenant persistence across tabs
  void setTargetTenant(String? tenantId) {
    final v = (tenantId?.trim().isEmpty ?? true) ? null : tenantId!.trim();
    state = state.copyWith(targetTenantId: v, targetTenantIdSet: true);
  }

  String? get targetTenantId => state.targetTenantId;

  // ── Account menu
  Future<void> handleAccountAction(
    HqAccountAction action, {
    required BuildContext context,
  }) async {
    switch (action) {
      case HqAccountAction.refreshClaims:
        await _refreshClaimsAndSession();
        _banner('Claims refreshed');
        break;

      case HqAccountAction.signOut:
        final ok = await _confirmSignOut(context);
        if (ok == true) {
          await fb.FirebaseAuth.instance.signOut();
          // Also clear local session cache for HQ.
          ref.invalidate(sessionControllerProvider(hqTenantId));
        }
        break;
    }
  }

  Future<void> _refreshClaimsAndSession() async {
    final u = fb.FirebaseAuth.instance.currentUser;
    if (u == null) return;

    // Force-refresh idToken (pulls latest custom claims)
    await u.getIdToken(true);

    // Refresh HQ session (tenant flow)
    await ref
        .read(sessionControllerProvider(hqTenantId).notifier)
        .refresh(forceNetwork: true);
  }

  // ── Busy / banners
  Future<T> withBusy<T>(
    BuildContext context,
    Future<T> Function() op, {
    String? success,
    String Function(Object, StackTrace)? errorBuilder,
  }) async {
    _setBusy(true);
    try {
      final out = await op();
      if (success != null && success.isNotEmpty) _banner(success);
      return out;
    } catch (e, st) {
      debugPrint('❌ [HQ.withBusy] $e\n$st');
      final msg = (errorBuilder != null) ? errorBuilder(e, st) : 'Error: $e';
      _banner(msg);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  void clearBanner() => state = state.copyWith(banner: '');
  void _setBusy(bool v) => state = state.copyWith(busy: v);
  void _banner(String msg) => state = state.copyWith(banner: msg);

  Future<bool?> _confirmSignOut(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out of HQ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
