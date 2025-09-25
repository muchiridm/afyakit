// lib/core/auth_users/controllers/login/login_controller.dart
import 'package:afyakit/app/afyakit_app.dart';
import 'package:afyakit/core/auth_users/models/login_outcome.dart';
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/core/auth_users/controllers/auth_session/session_controller.dart';
import 'package:afyakit/core/auth_users/controllers/login/login_engine.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/hq/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/core/auth_users/widgets/auth_gate.dart';

class LoginFormState {
  final TextEditingController loginController;
  final String password;
  final bool loading;

  // WhatsApp OTP state
  final bool waSending;
  final bool waVerifying;
  final bool waCodeSent;
  final String? waAttemptId;
  final String? waPhoneE164;

  LoginFormState({
    required this.loginController,
    this.password = '',
    this.loading = false,
    this.waSending = false,
    this.waVerifying = false,
    this.waCodeSent = false,
    this.waAttemptId,
    this.waPhoneE164,
  });

  LoginFormState copyWith({
    String? password,
    bool? loading,
    bool? waSending,
    bool? waVerifying,
    bool? waCodeSent,
    String? waAttemptId,
    String? waPhoneE164,
  }) {
    return LoginFormState(
      loginController: loginController,
      password: password ?? this.password,
      loading: loading ?? this.loading,
      waSending: waSending ?? this.waSending,
      waVerifying: waVerifying ?? this.waVerifying,
      waCodeSent: waCodeSent ?? this.waCodeSent,
      waAttemptId: waAttemptId ?? this.waAttemptId,
      waPhoneE164: waPhoneE164 ?? this.waPhoneE164,
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
    : super(LoginFormState(loginController: TextEditingController()));

  TextEditingController get emailController => state.loginController;

  void setPassword(String value) {
    state = state.copyWith(password: value);
  }

  LoginEngine? _engine;
  Future<void> _ensureDeps() async {
    _engine ??= await ref.read(loginEngineProvider(tenantId).future);
  }

  // ─────────────────────────────────────────────
  // 🔑 Email login
  // ─────────────────────────────────────────────
  Future<void> login() async {
    final email = EmailHelper.normalize(state.loginController.text);
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
        SnackService.showError(res.error.message);
        return;
      }

      final outcome = (res as Ok<LoginOutcome>).value;

      // Hydrate session and navigate
      await ref.read(sessionControllerProvider(tenantId).notifier).reload();
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );

      await Future<void>.delayed(Duration.zero);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (outcome.isActive) {
          SnackService.showSuccess('Welcome back, $email!');
        } else {
          SnackService.showInfo('Welcome, $email. Awaiting activation.');
        }
      });
    } catch (e, st) {
      debugPrint('❌ Login failed: $e\n$st');
      SnackService.showError('Login failed. Please try again.');
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  // ─────────────────────────────────────────────
  // 🔓 Logout
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

      state = LoginFormState(loginController: TextEditingController());

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
  // 🔄 Session Hydration
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
  // 📧 Password Reset
  // ─────────────────────────────────────────────
  Future<void> sendPasswordReset() async {
    final rawInput = state.loginController.text;
    final email = EmailHelper.normalize(rawInput);

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
      debugPrint('❌ Password reset error: $e\n$stack');
      SnackService.showError('Something went wrong. Please try again.');
    }
  }

  // ─────────────────────────────────────────────
  // 🟢 WhatsApp OTP flow
  // ─────────────────────────────────────────────
  Future<void> sendWaCode(String rawPhone) async {
    final phone = rawPhone.trim();
    if (phone.isEmpty) {
      SnackService.showError('Enter your WhatsApp number (E.164).');
      return;
    }

    state = state.copyWith(waSending: true);
    try {
      await _ensureDeps();
      final res = await _engine!.waStart(phone);
      if (res is Err) {
        SnackService.showError('Failed to send code. Try again.');
        return;
      }
      final start = (res as Ok).value;
      if (start.throttled) {
        SnackService.showInfo(
          'Please wait a moment before requesting another code.',
        );
      }
      state = state.copyWith(
        waSending: false,
        waCodeSent: true,
        waAttemptId: start.attemptId,
        waPhoneE164: phone,
      );
      SnackService.showSuccess('Code sent to WhatsApp.');
    } catch (e) {
      SnackService.showError('Failed to send code. Try again.');
    } finally {
      state = state.copyWith(waSending: false);
    }
  }

  Future<void> verifyWaCode(String rawCode) async {
    final code = rawCode.trim();
    final phone = (state.waPhoneE164 ?? '').trim();

    if (phone.isEmpty) {
      SnackService.showError('Enter your WhatsApp number first.');
      return;
    }
    if (code.length < 4) {
      SnackService.showError('Enter the 6-digit code.');
      return;
    }

    state = state.copyWith(waVerifying: true);
    try {
      await _ensureDeps();
      final res = await _engine!.waVerifyAndSignIn(
        phoneE164: phone,
        code: code,
        attemptId: state.waAttemptId,
      );
      if (res is Err<LoginOutcome>) {
        SnackService.showError(res.error.message);
        return;
      }
      final outcome = (res as Ok<LoginOutcome>).value;

      // Hydrate & navigate
      await ref.read(sessionControllerProvider(tenantId).notifier).reload();
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );

      await Future<void>.delayed(Duration.zero);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (outcome.isActive) {
          SnackService.showSuccess('Welcome back!');
        } else {
          SnackService.showInfo(
            'Welcome. Your account is invited and awaiting activation.',
          );
        }
      });
    } catch (e) {
      SnackService.showError(
        'Verification failed. Check the code and try again.',
      );
    } finally {
      state = state.copyWith(waVerifying: false);
    }
  }
}
