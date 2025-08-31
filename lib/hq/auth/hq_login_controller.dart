import 'package:afyakit/hq/auth/hq_auth_engine.dart';
import 'package:afyakit/hq/auth/hq_login_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:afyakit/shared/services/snack_service.dart';
import 'hq_auth_service.dart';

final hqLoginControllerProvider =
    StateNotifierProvider.autoDispose<HqLoginController, HqLoginState>(
      (ref) => HqLoginController(ref),
    );

class HqLoginController extends StateNotifier<HqLoginState> {
  HqLoginController(this.ref) : super(const HqLoginState());
  final Ref ref;

  HqAuthService get _svc => ref.read(hqAuthServiceProvider);

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: '', email: email.trim());
    try {
      final engine = ref.read(hqAuthEngineProvider);
      final res = await engine.signInAndGate(email: email, password: password);

      if (!mounted) return; // provider may be disposed if gate signs out

      if (!res.allowed) {
        const msg = 'Superadmin access required.';
        state = state.copyWith(isLoading: false, error: msg);
        SnackService.showError(msg);
        return;
      }

      state = state.copyWith(isLoading: false, isHqAllowed: true);
      SnackService.showSuccess('Welcome back');
    } on fb.FirebaseAuthException catch (ex) {
      if (!mounted) return;
      final msg = HqAuthService.friendlyError(ex);
      state = state.copyWith(isLoading: false, error: msg);
      SnackService.showError(msg);
    } catch (ex, st) {
      if (kDebugMode) debugPrint('🧨 HQ signIn error: $ex\n$st');
      if (!mounted) return;
      const msg = 'Sign-in failed.';
      state = state.copyWith(isLoading: false, error: msg);
      SnackService.showError(msg);
    }
  }

  Future<void> resetPassword(String email) async {
    final e = email.trim();
    if (e.isEmpty) {
      if (!mounted) return;
      const msg = 'Enter your email first to reset the password.';
      state = state.copyWith(error: msg);
      SnackService.showError(msg);
      return;
    }
    try {
      await _svc.sendPasswordReset(e);
      if (!mounted) return;
      SnackService.showSuccess('Password reset email sent to $e');
    } on fb.FirebaseAuthException catch (ex) {
      if (!mounted) return;
      final msg = HqAuthService.friendlyError(ex);
      state = state.copyWith(error: msg);
      SnackService.showError(msg);
    } catch (_) {
      if (!mounted) return;
      const msg = 'Failed to send reset email.';
      state = state.copyWith(error: msg);
      SnackService.showError(msg);
    }
  }

  Future<void> signOut() async {
    try {
      await _svc.signOut();
      if (!mounted) return;
      state = const HqLoginState();
      SnackService.showSuccess('Signed out');
    } catch (_) {
      if (!mounted) return;
      const msg = 'Failed to sign out.';
      state = state.copyWith(error: msg);
      SnackService.showError(msg);
    }
  }

  Future<void> refreshClaims() async {
    final ok = await ref.read(hqAuthEngineProvider).refreshAndGate();
    if (!mounted) return;
    state = state.copyWith(isHqAllowed: ok);
  }
}
