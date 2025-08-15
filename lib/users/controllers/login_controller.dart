import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:afyakit/users/services/firebase_auth_service.dart';
import 'package:afyakit/shared/utils/normalize/normalize_email.dart';
import 'package:afyakit/users/services/user_session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/users/controllers/user_session_controller.dart';
import 'package:afyakit/users/widgets/auth_gate.dart';
import 'package:afyakit/main.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/shared/providers/api_client_provider.dart';
import 'package:afyakit/shared/providers/api_route_provider.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/shared/screens/home_screen/home_screen.dart';
import 'package:afyakit/shared/services/snack_service.dart';

// ─────────────────────────────────────────────────────────────
// 🧠 State
// ─────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────
// 🧩 Provider
// ─────────────────────────────────────────────────────────────

final loginControllerProvider =
    StateNotifierProvider<LoginController, LoginFormState>((ref) {
      final tenantId = ref.read(tenantIdProvider);
      final apiRoutes = ref.read(apiRouteProvider);
      return LoginController(ref, tenantId: tenantId, apiRoutes: apiRoutes);
    });

// ─────────────────────────────────────────────────────────────
// 🔐 Controller
// ─────────────────────────────────────────────────────────────

class LoginController extends StateNotifier<LoginFormState> {
  final Ref ref;
  final String tenantId;
  final ApiRoutes apiRoutes;

  LoginController(this.ref, {required this.tenantId, required this.apiRoutes})
    : super(LoginFormState(emailController: TextEditingController()));

  TextEditingController get emailController => state.emailController;

  void setPassword(String value) {
    state = state.copyWith(password: value);
  }

  // ─────────────────────────────────────────────────────────────
  // 🔑 Login
  // ─────────────────────────────────────────────────────────────

  Future<void> login() async {
    final identity = ref.read(firebaseAuthServiceProvider);
    final email = EmailHelper.normalize(state.emailController.text);
    final password = state.password.trim();

    if (email.isEmpty || password.isEmpty) {
      SnackService.showError('Email and password are required.');
      return;
    }

    state = state.copyWith(loading: true);

    try {
      // 🧾 Check if email is registered (backend)
      final service = await _getUserSessionService();
      final isAllowed = await service.isEmailRegistered(email);

      if (!isAllowed) {
        SnackService.showError('This account is not registered.');
        return;
      }

      // 🔐 Sign in via Firebase
      await identity.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 🕰️ Ensure Firebase fully hydrates currentUser
      await identity.waitForUserSignIn();

      // 🔄 Refresh ID token for backend usage
      await identity.getIdToken(forceRefresh: true);

      // 🧠 Reload session (hydrates AuthUser, claims, etc)
      await ref.read(userSessionControllerProvider(tenantId).notifier).reload();

      // 🏠 Navigate to home screen
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

  // ─────────────────────────────────────────────────────────────
  // 🔓 Logout
  // ─────────────────────────────────────────────────────────────

  Future<void> logout() async {
    final identity = ref.read(firebaseAuthServiceProvider);

    try {
      await identity.signOut();

      ref.invalidate(userSessionControllerProvider);
      ref.invalidate(userSessionControllerProvider(tenantId));

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

  // ─────────────────────────────────────────────────────────────
  // 🔄 Session Hydration
  // ─────────────────────────────────────────────────────────────

  Future<void> initialize(Future<void> Function() onSessionReady) async {
    final identity = ref.read(firebaseAuthServiceProvider);
    final user = await identity.getCurrentUser();

    if (user == null) {
      debugPrint('⚠️ No signed-in Firebase user.');
      return;
    }

    try {
      await identity.getIdToken(forceRefresh: true);
      await onSessionReady();
    } catch (e) {
      debugPrint('❌ AuthController.initialize error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 📧 Password Reset
  // ─────────────────────────────────────────────────────────────

  Future<void> sendPasswordReset() async {
    final rawInput = state.emailController.text;
    final email = EmailHelper.normalize(rawInput);

    debugPrint('📨 Raw input: $rawInput');
    debugPrint('📨 Normalized email: $email');

    if (!EmailHelper.isValid(email)) {
      SnackService.showError(
        'Please enter a valid email to reset your password.',
      );
      debugPrint('❌ Invalid email format: $email');
      return;
    }

    try {
      final sessionService = await _getUserSessionService();
      debugPrint('✅ Got UserSessionService');

      final isAllowed = await sessionService.isEmailRegistered(email);
      debugPrint('🔍 Email registration check: $email → isAllowed: $isAllowed');

      if (!isAllowed) {
        SnackService.showError('This email is not registered in the system.');
        return;
      }

      debugPrint('📡 Sending password reset email for: $email');
      await sessionService.sendPasswordResetEmail(email);
      SnackService.showSuccess('Password reset link sent to $email');
    } catch (e, stack) {
      debugPrint('❌ Password reset error: $e');
      debugPrint('🧱 Stack trace:\n$stack');
      SnackService.showError('Something went wrong. Please try again.');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 🔧 Helper to get UserSessionService
  // ─────────────────────────────────────────────────────────────
  Future<UserSessionService> _getUserSessionService() async {
    final tokenProviderInstance = ref.read(tokenProvider);
    final client = await ref.read(apiClientProvider.future);
    return UserSessionService(
      client: client,
      routes: apiRoutes,
      tokenProvider: tokenProviderInstance,
    );
  }
}
