// lib/core/auth/controllers/login_controller.dart

import 'package:afyakit/core/auth/controllers/session_controller.dart';
import 'package:afyakit/core/auth/services/auth_service.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OtpChannel { wa, sms, email }

@immutable
class LoginState {
  final bool sending;
  final bool verifying;
  final bool codeSent;
  final String? attemptId;

  /// 🔑 UI signal: close OTP screen
  final bool closeScreen;

  const LoginState({
    required this.sending,
    required this.verifying,
    required this.codeSent,
    required this.attemptId,
    required this.closeScreen,
  });

  factory LoginState.initial() => const LoginState(
    sending: false,
    verifying: false,
    codeSent: false,
    attemptId: null,
    closeScreen: false,
  );

  LoginState copyWith({
    bool? sending,
    bool? verifying,
    bool? codeSent,
    String? attemptId,
    bool? closeScreen,
  }) {
    return LoginState(
      sending: sending ?? this.sending,
      verifying: verifying ?? this.verifying,
      codeSent: codeSent ?? this.codeSent,
      attemptId: attemptId ?? this.attemptId,
      closeScreen: closeScreen ?? this.closeScreen,
    );
  }
}

final loginControllerProvider =
    StateNotifierProvider<LoginController, LoginState>((ref) {
      final tenantId = ref.watch(tenantSlugProvider);
      return LoginController(ref, tenantId);
    });

class LoginController extends StateNotifier<LoginState> {
  LoginController(this._ref, this._tenantId) : super(LoginState.initial());

  final Ref _ref;
  final String _tenantId;

  // ─────────────────────────────────────────────
  // Public API (UI calls only these)
  // ─────────────────────────────────────────────

  void reset() {
    if (!mounted) return;
    state = LoginState.initial();
  }

  Future<void> sendCode({
    required String phoneE164,
    String? email,
    required OtpChannel channel,
  }) async {
    final phone = phoneE164.trim();
    final trimmedEmail = email?.trim();

    if (phone.isEmpty) {
      SnackService.showError('Enter phone number in +2547… format');
      return;
    }

    if (channel == OtpChannel.email &&
        (trimmedEmail == null || trimmedEmail.isEmpty)) {
      SnackService.showError('Enter the email address');
      return;
    }

    state = state.copyWith(sending: true);

    try {
      final auth = await _ref.read(authServiceProvider(_tenantId).future);

      final res = switch (channel) {
        OtpChannel.wa => await auth.startWaOtp(phone),
        OtpChannel.sms => await auth.startSmsOtp(phone),
        OtpChannel.email => await auth.startEmailOtp(
          phoneE164: phone,
          email: trimmedEmail!,
        ),
      };

      if (!res.ok) {
        SnackService.showError('Failed to send code');
        return;
      }

      state = state.copyWith(codeSent: true, attemptId: res.attemptId);

      SnackService.showInfo(
        channel == OtpChannel.email ? 'Code sent to your email' : 'Code sent',
      );
    } finally {
      if (mounted) {
        state = state.copyWith(sending: false);
      }
    }
  }

  Future<void> verifyCode({
    required String phoneE164,
    required String code,
    String? email,
    required OtpChannel channel,
  }) async {
    final trimmedCode = code.trim();

    if (trimmedCode.length != 6) {
      SnackService.showError('Enter 6-digit code');
      return;
    }

    state = state.copyWith(verifying: true);

    try {
      final session = _ref.read(sessionControllerProvider(_tenantId).notifier);

      await session.signInWithOtp(
        phoneE164: phoneE164.trim(),
        code: trimmedCode,
        attemptId: state.attemptId,
        email: channel == OtpChannel.email ? email?.trim() : null,
      );

      SnackService.showSuccess('Signed in!');

      // ✅ single source of truth
      state = LoginState.initial().copyWith(closeScreen: true);
    } catch (e) {
      SnackService.showError('Could not verify code');
    } finally {
      if (mounted) {
        state = state.copyWith(verifying: false);
      }
    }
  }
}
