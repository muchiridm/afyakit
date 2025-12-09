// lib/core/auth_users/controllers/session_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/modules/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/modules/core/auth_users/services/auth_service.dart';

final sessionControllerProvider =
    StateNotifierProvider.family<
      SessionController,
      AsyncValue<AuthUser?>,
      String
    >((ref, tenantId) => SessionController(ref, tenantId));

class SessionController extends StateNotifier<AsyncValue<AuthUser?>> {
  SessionController(this.ref, this.tenantId)
    : super(const AsyncValue.loading());

  final Ref ref;
  final String tenantId;

  Future<void> init() async {
    state = const AsyncValue.loading();

    final fbUser = fb.FirebaseAuth.instance.currentUser;
    if (fbUser == null) {
      state = const AsyncValue.data(null);
      return;
    }

    try {
      final svc = await ref.read(authServiceProvider(tenantId).future);
      final user = await svc.loadSession();
      state = AsyncValue.data(user);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
    }
  }

  /// Centralised OTP sign-in:
  /// - verifies OTP via backend (optionally with email)
  /// - uses AuthService cache / session endpoint
  /// - updates Riverpod state so UI reacts immediately
  Future<void> signInWithOtp({
    required String phoneE164,
    required String code,
    String? attemptId,
    String? email,
  }) async {
    state = const AsyncValue.loading();

    // 🔍 FE LOG
    // ignore: avoid_print
    print(
      '[OTP][FE] SessionController.signInWithOtp → '
      'phone=$phoneE164 code=$code attemptId=$attemptId email=$email',
    );

    try {
      final svc = await ref.read(authServiceProvider(tenantId).future);

      // Verify with backend (also signs in Firebase)
      await svc.verifyOtp(
        phoneE164: phoneE164,
        code: code,
        attemptId: attemptId,
        email: email,
      );

      // Prefer cached user; fall back to explicit session fetch
      final user = svc.currentUser ?? await svc.loadSession();

      // 🔍 FE LOG
      // ignore: avoid_print
      print(
        '[OTP][FE] SessionController.signInWithOtp → session loaded '
        'uid=${user.uid} email=${user.email} phone=${user.phoneNumber}',
      );

      state = AsyncValue.data(user);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow; // allow UI to handle DioException codes
    }
  }

  Future<void> logOut() async {
    final svc = await ref.read(authServiceProvider(tenantId).future);
    await svc.logOut();
    state = const AsyncValue.data(null);
  }
}
