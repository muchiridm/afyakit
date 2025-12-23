import 'package:afyakit/features/hq/base/shell/hq_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// auth controllers/services (delegation only)
import 'package:afyakit/features/hq/base/auth/hq_auth_controller.dart';
import 'package:afyakit/features/hq/base/auth/hq_auth_service.dart';

final hqControllerProvider = StateNotifierProvider<HqController, HqState>(
  (ref) => HqController(ref),
);

/// Handy read-only provider for current user email (for the top-right menu label).
final hqCurrentEmailProvider = Provider<String?>(
  (ref) => ref.watch(hqAuthServiceProvider).currentUser?.email,
);

enum HqAccountAction { refreshClaims, signOut }

class HqController extends StateNotifier<HqState> {
  HqController(this.ref) : super(const HqState());
  final Ref ref;

  // ── Navigation + search
  void setTab(int index) => state = state.copyWith(tabIndex: index);
  void setUserSearch(String q) => state = state.copyWith(userSearch: q.trim());

  // ── Account menu (delegates to HQ auth controller)
  Future<void> handleAccountAction(
    HqAccountAction action, {
    required BuildContext context,
  }) async {
    switch (action) {
      case HqAccountAction.refreshClaims:
        await ref
            .read(hqAuthControllerProvider.notifier)
            .refreshGate(signOutIfDenied: false);
        _banner('Claims refreshed');
        break;

      case HqAccountAction.signOut:
        final ok = await _confirmSignOut(context);
        if (ok == true) {
          await ref.read(hqAuthControllerProvider.notifier).signOut();
        }
        break;
    }
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
