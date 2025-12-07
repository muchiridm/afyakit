// lib/core/auth_users/controllers/login_controller.dart

import 'package:afyakit/core/auth_users/controllers/session_controller.dart';
import 'package:afyakit/core/auth_users/services/auth_service.dart';
import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Public enum so both controller + UI can share it.
enum OtpChannel { wa, sms, email }

@immutable
class LoginState {
  final bool sending;
  final bool verifying;
  final bool codeSent;
  final String? attemptId;

  const LoginState({
    required this.sending,
    required this.verifying,
    required this.codeSent,
    required this.attemptId,
  });

  factory LoginState.initial() => const LoginState(
    sending: false,
    verifying: false,
    codeSent: false,
    attemptId: null,
  );

  LoginState copyWith({
    bool? sending,
    bool? verifying,
    bool? codeSent,
    String? attemptId,
  }) {
    return LoginState(
      sending: sending ?? this.sending,
      verifying: verifying ?? this.verifying,
      codeSent: codeSent ?? this.codeSent,
      attemptId: attemptId ?? this.attemptId,
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

  /// Reset attempt state when user switches channel.
  void resetAttempt() {
    if (!mounted) return;
    state = state.copyWith(codeSent: false, attemptId: null);
  }

  /// Send OTP via selected channel.
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
      SnackService.showError('Enter the email address to send the code to');
      return;
    }

    if (!mounted) return;
    state = state.copyWith(sending: true, codeSent: false, attemptId: null);

    try {
      final auth = await _ref.read(authServiceProvider(_tenantId).future);

      if (!mounted) return;

      final res = switch (channel) {
        OtpChannel.wa => await auth.startWaOtp(phone),
        OtpChannel.sms => await auth.startSmsOtp(phone),
        OtpChannel.email => await auth.startEmailOtp(
          phoneE164: phone,
          email: trimmedEmail!,
        ),
      };

      if (!mounted) return;

      if (res.throttled) {
        SnackService.showError('Too many attempts. Try again later.');
        return;
      }

      if (!res.ok) {
        SnackService.showError('Failed to send code. Please try again.');
        return;
      }

      state = state.copyWith(codeSent: true, attemptId: res.attemptId);

      switch (channel) {
        case OtpChannel.wa:
          SnackService.showInfo('Code sent on WhatsApp');
          break;
        case OtpChannel.sms:
          SnackService.showInfo('Code sent via SMS');
          break;
        case OtpChannel.email:
          SnackService.showInfo('Code sent to your email');
          break;
      }
    } on DioException catch (dioErr) {
      final status = dioErr.response?.statusCode;
      final data = dioErr.response?.data;
      final rawError = (data is Map && data['error'] is String)
          ? data['error'] as String
          : data?.toString();

      if (status == 409) {
        if (kDebugMode) {
          final existingEmail = _extractExistingEmail(rawError);
          // ignore: avoid_print
          print(
            '[OTP][FE] EMAIL_CONFLICT (start) '
            'phone=$phone existing=$existingEmail raw=$rawError',
          );
        }

        SnackService.showError(
          'This phone number is already linked to a different email in our system.\n'
          'To continue, use that email address to log in by email, or choose WhatsApp / SMS instead.',
        );
      } else if (status == 429) {
        SnackService.showError('Too many attempts. Try again later.');
      } else {
        SnackService.showError('Could not send code. Please try again.');
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('Email/WA/SMS OTP start failed: $e\n$st');
      SnackService.showError('Network error while sending code');
    } finally {
      if (!mounted) return;
      state = state.copyWith(sending: false);
    }
  }

  /// Verify OTP and sign in via SessionController.
  /// Returns true on success so the UI can react (if it wants).
  Future<bool> verifyCode({
    required String phoneE164,
    required String code,
    String? email,
    required OtpChannel channel,
  }) async {
    final phone = phoneE164.trim();
    final trimmedEmail = email?.trim();
    final trimmedCode = code.trim();

    if (trimmedCode.length != 6) {
      SnackService.showError('Enter 6-digit code');
      return false;
    }

    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[OTP][FE] LoginController.verifyCode → channel=$channel '
        'phone=$phone code=$trimmedCode '
        'email=${channel == OtpChannel.email ? trimmedEmail : null} '
        'attemptId=${state.attemptId}',
      );
    }

    if (!mounted) return false;
    state = state.copyWith(verifying: true);

    try {
      final session = _ref.read(sessionControllerProvider(_tenantId).notifier);

      await session.signInWithOtp(
        phoneE164: phone,
        code: trimmedCode,
        attemptId: state.attemptId,
        email: channel == OtpChannel.email ? trimmedEmail : null,
      );

      SnackService.showSuccess('Signed in!');
      return true;
    } on DioException catch (dioErr) {
      final status = dioErr.response?.statusCode;
      final data = dioErr.response?.data;
      final codeStr = (data is Map && data['error'] is String)
          ? data['error'] as String
          : null;
      final rawError = (data is Map && data['error'] is String)
          ? data['error'] as String
          : data?.toString();

      if (status == 401 &&
          (codeStr == 'INVALID_CODE' || codeStr == 'EXPIRED')) {
        SnackService.showError('Invalid or expired code');
      } else if (status == 429) {
        SnackService.showError('Too many attempts. Try again later.');
      } else if (status == 409) {
        if (kDebugMode) {
          final existingEmail = _extractExistingEmail(rawError);
          // ignore: avoid_print
          print(
            '[OTP][FE] EMAIL_CONFLICT (verify) '
            'phone=$phone existing=$existingEmail raw=$rawError',
          );
        }

        SnackService.showError(
          'This phone number is already linked to a different email in our system.\n'
          'If this doesn’t look right, please contact support or try WhatsApp / SMS login instead.',
        );
      } else {
        SnackService.showError('Could not verify code. Please try again.');
      }
      return false;
    } catch (e, st) {
      // ignore: avoid_print
      print('OTP verify failed: $e\n$st');
      SnackService.showError('Something went wrong signing you in');
      return false;
    } finally {
      // No `return` in finally – just guard the state update.
      if (mounted) {
        state = state.copyWith(verifying: false);
      }
    }
  }

  /// Parse "existing=foo@bar.com" from backend error strings like:
  /// "Email conflict for account: existing=foo@bar.com, requested=bar@baz.com"
  /// Used only for debug logs; never surfaced to the user.
  String? _extractExistingEmail(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'existing=([^,]+)').firstMatch(raw);
    return match?.group(1)?.trim();
  }
}
