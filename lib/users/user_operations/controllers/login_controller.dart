import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/users/user_operations/controllers/session_controller.dart';
import 'package:afyakit/users/user_operations/engines/login_engine.dart';
import 'package:afyakit/users/user_operations/providers/user_operations_engine_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/main.dart';
import 'package:afyakit/shared/screens/home_screen/home_screen.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/users/widgets/auth_gate.dart';

class LoginFormState {
  final TextEditingController emailController;
  final String password;
  final bool loading;

  LoginFormState({
    required this.emailController,
    this.password = '',
    this.loading = false,
  });

  LoginFormState copyWith({String? password, bool? loading}) {
    return LoginFormState(
      emailController: emailController,
      password: password ?? this.password,
      loading: loading ?? this.loading,
    );
  }
}

final loginControllerProvider =
    StateNotifierProvider<LoginController, LoginFormState>((ref) {
      final tenantId = ref.read(tenantIdProvider);
      return LoginController(ref, tenantId: tenantId);
    });

class LoginController extends StateNotifier<LoginFormState> {
  final Ref ref;
  final String tenantId;

  LoginController(this.ref, {required this.tenantId})
    : super(LoginFormState(emailController: TextEditingController()));

  TextEditingController get emailController => state.emailController;

  void setPassword(String value) {
    state = state.copyWith(password: value);
  }

  LoginEngine? _engine;
  Future<void> _ensureDeps() async {
    _engine ??= await ref.read(loginEngineProvider(tenantId).future);
  }

  // ─────────────────────────────────────────────
  // 🔑 Login
  // ─────────────────────────────────────────────
  Future<void> login() async {
    final email = EmailHelper.normalize(state.emailController.text);
    final password = state.password.trim();

    if (email.isEmpty || password.isEmpty) {
      SnackService.showError('Email and password are required.');
      return;
    }

    state = state.copyWith(loading: true);

    try {
      await _ensureDeps();
      final res = await _engine!.login(email, password);

      if (res is Err<LoginOutcome>) {
        SnackService.showError('Login failed. Please try again.');
        return;
      }

      final outcome = (res as Ok<LoginOutcome>).value;

      if (!outcome.registered) {
        SnackService.showError('This account is not registered.');
        return;
      }

      // Claims/AuthUser hydration
      await ref.read(sessionControllerProvider(tenantId).notifier).reload();

      // Navigate to home
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );

      SnackService.showSuccess('Welcome back, $email!');
    } catch (e, st) {
      debugPrint('❌ Login failed: $e\n$st');
      SnackService.showError('Login failed. Please try again.');
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  // ─────────────────────────────────────────────
  // 🔓 Logout (engine-only)
  // ─────────────────────────────────────────────
  Future<void> logout() async {
    try {
      await _ensureDeps();
      final res = await _engine!.signOut();
      if (res is Err<void>) {
        SnackService.showError('Sign out failed.');
        return;
      }

      ref.invalidate(sessionControllerProvider);
      ref.invalidate(sessionControllerProvider(tenantId));

      state = LoginFormState(emailController: TextEditingController());

      await Future.delayed(const Duration(milliseconds: 300));

      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    } catch (e, st) {
      debugPrint('❌ Sign out failed: $e\n$st');
      SnackService.showError('Sign out failed.');
    }
  }

  // ─────────────────────────────────────────────
  // 🔄 Session Hydration (engine-only)
  // ─────────────────────────────────────────────
  Future<void> initialize(Future<void> Function() onSessionReady) async {
    try {
      await _ensureDeps();
      final signedIn = await _engine!.isSignedIn();
      if (!signedIn) {
        debugPrint('⚠️ No signed-in Firebase user.');
        return;
      }

      final tokRes = await _engine!.refreshIdToken();
      if (tokRes is Err<void>) {
        debugPrint('⚠️ Token refresh failed during initialize.');
      }

      await onSessionReady();
    } catch (e) {
      debugPrint('❌ LoginController.initialize error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // 📧 Password Reset (engine-only)
  // ─────────────────────────────────────────────
  Future<void> sendPasswordReset() async {
    final rawInput = state.emailController.text;
    final email = EmailHelper.normalize(rawInput);

    debugPrint('📨 Raw input: $rawInput');
    debugPrint('📨 Normalized email: $email');

    if (email.isEmpty) {
      SnackService.showError(
        'Please enter a valid email to reset your password.',
      );
      return;
    }

    try {
      await _ensureDeps();
      final res = await _engine!.sendPasswordReset(email);

      if (res is Err<void>) {
        SnackService.showError('This email is not registered in the system.');
        return;
      }

      SnackService.showSuccess('Password reset link sent to $email');
    } catch (e, stack) {
      debugPrint('❌ Password reset error: $e');
      debugPrint('🧱 Stack trace:\n$stack');
      SnackService.showError('Something went wrong. Please try again.');
    }
  }
}
