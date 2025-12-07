import 'package:afyakit/shared/services/snack_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hq_auth_service.dart';

@immutable
class HqAuthState {
  final bool checking;
  final bool isHqAllowed;
  final String? error;
  final Map<String, dynamic> claims;

  const HqAuthState({
    this.checking = false,
    this.isHqAllowed = false,
    this.error,
    this.claims = const {},
  });

  HqAuthState copyWith({
    bool? checking,
    bool? isHqAllowed,
    String? error, // '' clears
    Map<String, dynamic>? claims,
  }) {
    return HqAuthState(
      checking: checking ?? this.checking,
      isHqAllowed: isHqAllowed ?? this.isHqAllowed,
      error: (error == '') ? null : (error ?? this.error),
      claims: claims ?? this.claims,
    );
  }
}

final hqAuthControllerProvider =
    StateNotifierProvider.autoDispose<HqAuthController, HqAuthState>(
      (ref) => HqAuthController(ref),
    );

class HqAuthController extends StateNotifier<HqAuthState> {
  HqAuthController(this.ref) : super(const HqAuthState());

  final Ref ref;

  HqAuthService get _svc => ref.read(hqAuthServiceProvider);

  /// Re-evaluate the current user's HQ gate.
  /// Optionally sign them out immediately if not allowed.
  Future<void> refreshGate({bool signOutIfDenied = false}) async {
    state = state.copyWith(checking: true, error: '');

    try {
      final user = _svc.currentUser;
      if (user == null) {
        state = state.copyWith(
          checking: false,
          isHqAllowed: false,
          error: 'Not signed in.',
          claims: const {},
        );
        return;
      }

      final claims = await _svc.getClaims(force: true);
      final isSuper =
          claims['isSuperAdmin'] == true || claims['superadmin'] == true;

      if (!isSuper && signOutIfDenied) {
        await _svc.signOut();
        SnackService.showError('Superadmin access required.');
      }

      if (!mounted) return;

      state = state.copyWith(
        checking: false,
        isHqAllowed: isSuper,
        claims: claims,
        error: isSuper ? '' : 'Superadmin access required.',
      );

      if (kDebugMode) {
        debugPrint(
          '🔐 [HqAuthController] uid=${user.uid} '
          'phone=${user.phoneNumber} email=${user.email} '
          'isSuperAdmin=$isSuper claims=$claims',
        );
      }
    } on fb.FirebaseAuthException catch (e) {
      final msg = HqAuthService.friendlyError(e);
      if (!mounted) return;
      state = state.copyWith(checking: false, error: msg);
      SnackService.showError(msg);
    } catch (e, st) {
      if (kDebugMode) debugPrint('🧨 [HqAuthController] $e\n$st');
      if (!mounted) return;
      const msg = 'Failed to verify HQ permissions.';
      state = state.copyWith(checking: false, error: msg);
      SnackService.showError(msg);
    }
  }

  Future<void> signOut() async {
    try {
      await _svc.signOut();
      if (!mounted) return;
      state = const HqAuthState();
      SnackService.showSuccess('Signed out');
    } catch (_) {
      if (!mounted) return;
      const msg = 'Failed to sign out.';
      state = state.copyWith(error: msg);
      SnackService.showError(msg);
    }
  }
}
