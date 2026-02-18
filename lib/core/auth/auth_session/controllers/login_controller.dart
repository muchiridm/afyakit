// lib/core/auth/auth_session/controllers/login_controller.dart

import 'dart:async';

import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/auth_session/models/start_response.dart';
import 'package:afyakit/core/auth/auth_session/services/auth_api_exception.dart';
import 'package:afyakit/core/auth/auth_session/services/auth_service.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LoginStep { phone, otp, emailEntry, emailOtp, nameEntry }

@immutable
class LoginState {
  const LoginState({
    required this.step,
    required this.sending,
    required this.verifying,
    required this.savingProfile,
    required this.attemptId,
    required this.channel,
    required this.maskedTo,
    required this.emailAttemptId,
    required this.emailMaskedTo,
    required this.closeScreen,
    required this.stepHint,
    required this.phoneNumber,
  });

  final LoginStep step;

  final bool sending;
  final bool verifying;
  final bool savingProfile;

  final String? attemptId;
  final String? channel;
  final String? maskedTo;

  final String? emailAttemptId;
  final String? emailMaskedTo;

  final bool closeScreen;
  final String? stepHint;

  /// Persist the phone the user entered (E164) – required for EMAIL_REQUIRED binding.
  final String? phoneNumber;

  factory LoginState.initial() => const LoginState(
    step: LoginStep.phone,
    sending: false,
    verifying: false,
    savingProfile: false,
    attemptId: null,
    channel: null,
    maskedTo: null,
    emailAttemptId: null,
    emailMaskedTo: null,
    closeScreen: false,
    stepHint: null,
    phoneNumber: null,
  );

  LoginState copyWith({
    LoginStep? step,
    bool? sending,
    bool? verifying,
    bool? savingProfile,

    String? attemptId,
    bool clearAttemptId = false,

    String? channel,

    String? maskedTo,
    bool clearMaskedTo = false,

    String? emailAttemptId,
    bool clearEmailAttemptId = false,

    String? emailMaskedTo,
    bool clearEmailMaskedTo = false,

    bool? closeScreen,
    String? stepHint,

    String? phoneNumber,
    bool clearPhoneNumber = false,
  }) {
    return LoginState(
      step: step ?? this.step,
      sending: sending ?? this.sending,
      verifying: verifying ?? this.verifying,
      savingProfile: savingProfile ?? this.savingProfile,

      attemptId: clearAttemptId ? null : (attemptId ?? this.attemptId),
      channel: channel ?? this.channel,
      maskedTo: clearMaskedTo ? null : (maskedTo ?? this.maskedTo),

      emailAttemptId: clearEmailAttemptId
          ? null
          : (emailAttemptId ?? this.emailAttemptId),
      emailMaskedTo: clearEmailMaskedTo
          ? null
          : (emailMaskedTo ?? this.emailMaskedTo),

      closeScreen: closeScreen ?? this.closeScreen,
      stepHint: stepHint ?? this.stepHint,

      phoneNumber: clearPhoneNumber ? null : (phoneNumber ?? this.phoneNumber),
    );
  }

  bool get busy => sending || verifying || savingProfile;
}

final loginControllerProvider =
    StateNotifierProvider<LoginController, LoginState>((ref) {
      final tenantId = ref.watch(tenantIdProvider);
      return LoginController(ref, tenantId);
    });

class LoginController extends StateNotifier<LoginState> {
  LoginController(this._ref, this._tenantId) : super(LoginState.initial()) {
    state = state.copyWith(stepHint: _hintForStep(LoginStep.phone));
  }

  final Ref _ref;
  final String _tenantId;

  Future<AuthService> _auth() =>
      _ref.read(authServiceProvider(_tenantId).future);

  // ─────────────────────────────────────────────
  // Firebase phone state (kept out of Riverpod state)
  // ─────────────────────────────────────────────

  fb.ConfirmationResult? _webResult;
  String? _mobileVerificationId;

  /// Keep last phone so "Resend code" works without UI re-providing it.
  String? _lastPhoneE164;

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  bool _looksLikeEmail(String s) {
    final v = s.trim();
    return v.isNotEmpty && v.contains('@') && v.contains('.');
  }

  String _maskPhone(String e164) {
    final v = e164.trim();
    if (v.length <= 6) return v;
    final start = v.substring(0, 4);
    final end = v.substring(v.length - 2);
    return '$start•••$end';
  }

  String _prettyDestination({String? maskedTo, String? channel}) {
    final m = (maskedTo ?? '').trim();
    if (m.isNotEmpty) return m;
    final ch = (channel ?? '').trim();
    return ch.isNotEmpty ? ch : '';
  }

  String _hintForStep(LoginStep step) {
    switch (step) {
      case LoginStep.phone:
        return 'Enter your phone number to continue.';
      case LoginStep.otp:
        final dest = _prettyDestination(
          maskedTo: state.maskedTo,
          channel: state.channel,
        );
        final mode = ((state.channel ?? '').trim().toLowerCase() == 'sms')
            ? 'SMS'
            : 'email';
        return dest.isNotEmpty
            ? 'Enter the 6-digit code we sent via $mode to $dest.'
            : 'Enter the 6-digit code.';
      case LoginStep.emailEntry:
        return 'Add your email. We’ll send a 6-digit code to confirm it.';
      case LoginStep.emailOtp:
        final where = (state.emailMaskedTo ?? '').trim();
        return where.isNotEmpty
            ? 'Enter the code sent to $where'
            : 'Enter the email code.';
      case LoginStep.nameEntry:
        return 'Add your display name to finish setup.';
    }
  }

  LoginStep _mapOtpNextToLoginStep(OtpNextStep next) {
    switch (next) {
      case OtpNextStep.collectEmail:
        return LoginStep.emailEntry;
      case OtpNextStep.collectName:
        return LoginStep.nameEntry;
      case OtpNextStep.done:
        return LoginStep.phone; // not used
    }
  }

  void _closeNow() {
    if (!mounted) return;
    state = LoginState.initial().copyWith(closeScreen: true);
  }

  void _resetFirebaseOtpState() {
    _webResult = null;
    _mobileVerificationId = null;
  }

  Future<OtpNextStep> _postAuthNextStep(AuthService svc) async {
    final status = await svc.checkUserStatusAfterFirebaseLogin();
    return status.next;
  }

  ({String firstName, String lastName}) _deriveNamesFromDisplayName(
    String displayName,
  ) {
    final s = displayName.trim();
    if (s.isEmpty) return (firstName: '-', lastName: '-');

    final parts = s
        .split(RegExp(r'\s+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) return (firstName: '-', lastName: '-');
    if (parts.length == 1) return (firstName: parts.first, lastName: '-');

    return (firstName: parts.first, lastName: parts.sublist(1).join(' '));
  }

  // ─────────────────────────────────────────────
  // Navigation helpers
  // ─────────────────────────────────────────────

  void reset() {
    if (!mounted) return;

    _resetFirebaseOtpState();
    _lastPhoneE164 = null;

    state = LoginState.initial().copyWith(
      stepHint: _hintForStep(LoginStep.phone),
      clearAttemptId: true,
      clearEmailAttemptId: true,
      clearMaskedTo: true,
      clearEmailMaskedTo: true,
      clearPhoneNumber: true,
    );
  }

  void backToPhone() => reset();

  void backToEmailEntry() {
    if (!mounted) return;
    state = state.copyWith(
      step: LoginStep.emailEntry,
      emailAttemptId: null,
      emailMaskedTo: null,
      stepHint: _hintForStep(LoginStep.emailEntry),
    );
  }

  Future<void> resendLoginOtp() async {
    final phone = (_lastPhoneE164 ?? '').trim();
    if (phone.isEmpty) {
      SnackService.showError('Enter phone number again.');
      reset();
      return;
    }

    if (!mounted || state.verifying || state.savingProfile) return;

    state = state.copyWith(
      sending: false,
      closeScreen: false,
      stepHint: 'Re-checking your account…',
    );

    await sendCode(phoneE164: phone);
  }

  // ─────────────────────────────────────────────
  // Step 1: phone => backend decides next
  // ─────────────────────────────────────────────

  Future<void> sendCode({required String phoneE164}) async {
    final phone = phoneE164.trim();

    if (phone.isEmpty || !phone.startsWith('+') || phone.length < 8) {
      SnackService.showError('Enter phone number in +2547… format');
      return;
    }

    if (!mounted || state.busy) return;

    // ✅ Persist phone ASAP (used later for EMAIL_REQUIRED → email/start(login))
    _lastPhoneE164 = phone;

    state = state.copyWith(
      sending: true,
      closeScreen: false,
      phoneNumber: phone,
      stepHint: 'Checking your account…',
    );

    _resetFirebaseOtpState();

    StartResponse start;
    try {
      final svc = await _auth();

      // ✅ startAutoOtp may return 400 control-flow (EMAIL_REQUIRED).
      // AuthService already allows <500 statuses.
      start = await svc.startAutoOtp(phone);
    } catch (err) {
      SnackService.showError('$err');
      if (kDebugMode) debugPrint('⚠️ [login] startAutoOtp failed: $err');
      if (!mounted) return;

      state = state.copyWith(
        sending: false,
        step: LoginStep.phone,
        stepHint: _hintForStep(LoginStep.phone),
      );
      return;
    }

    if (!mounted) return;

    // Throttle
    if (start.throttled == true) {
      SnackService.showInfo('Please wait before requesting another code.');
      state = state.copyWith(
        sending: false,
        step: LoginStep.phone,
        stepHint: _hintForStep(LoginStep.phone),
      );
      return;
    }

    // ✅ PATH 0: Somalia (+252) new users => EMAIL_REQUIRED => collect email
    if (start.requiresCollectEmail) {
      final masked = (start.maskedTo ?? '').trim().isNotEmpty
          ? start.maskedTo!.trim()
          : _maskPhone(phone);

      state = state.copyWith(
        sending: false,
        step: LoginStep.emailEntry,
        clearAttemptId: true,
        channel: (start.channel ?? 'email').trim(),
        maskedTo: masked,
        stepHint: _hintForStep(LoginStep.emailEntry),
        // phoneNumber stays persisted ✅
      );
      return;
    }

    // PATH A: client-driven Firebase SMS flow
    if (start.requiresFirebaseSmsClientAction) {
      state = state.copyWith(stepHint: 'Sending SMS code…');

      try {
        if (kIsWeb) {
          _webResult = await fb.FirebaseAuth.instance.signInWithPhoneNumber(
            phone,
          );
        } else {
          _mobileVerificationId = await _startMobilePhoneOtp(phoneE164: phone);
        }
      } on fb.FirebaseAuthException catch (e) {
        SnackService.showError('Could not send SMS code (${e.code}).');
        if (kDebugMode) {
          debugPrint(
            '⚠️ [login] firebase start failed: ${e.code} ${e.message}',
          );
        }
        if (!mounted) return;

        state = state.copyWith(
          sending: false,
          step: LoginStep.phone,
          stepHint: _hintForStep(LoginStep.phone),
        );
        return;
      } catch (err) {
        SnackService.showError('Could not send SMS code. Try again.');
        if (kDebugMode) debugPrint('⚠️ [login] firebase start failed: $err');
        if (!mounted) return;

        state = state.copyWith(
          sending: false,
          step: LoginStep.phone,
          stepHint: _hintForStep(LoginStep.phone),
        );
        return;
      }

      final masked = (start.maskedTo ?? '').trim().isNotEmpty
          ? start.maskedTo!.trim()
          : _maskPhone(phone);

      state = state.copyWith(
        sending: false,
        step: LoginStep.otp,
        clearAttemptId: true, // SMS path does not use backend attemptId
        channel: 'sms',
        maskedTo: masked,
        stepHint: _hintForStep(LoginStep.otp),
      );
      return;
    }

    // PATH B: backend email attempt (returning user)
    final attemptId = (start.attemptId ?? '').trim();
    if (attemptId.isEmpty) {
      SnackService.showError('Login start returned no attempt. Try again.');
      state = state.copyWith(
        sending: false,
        step: LoginStep.phone,
        stepHint: _hintForStep(LoginStep.phone),
      );
      return;
    }

    final masked = (start.maskedTo ?? '').trim().isNotEmpty
        ? start.maskedTo!.trim()
        : phone;

    state = state.copyWith(
      sending: false,
      step: LoginStep.otp,
      attemptId: attemptId,
      channel: (start.channel ?? 'email').trim(),
      maskedTo: masked,
      stepHint: _hintForStep(LoginStep.otp),
    );
  }

  Future<String> _startMobilePhoneOtp({
    required String phoneE164,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final phone = phoneE164.trim();
    if (phone.isEmpty) {
      throw fb.FirebaseAuthException(
        code: 'invalid-phone-number',
        message: 'Phone number is empty',
      );
    }

    final completer = Completer<String>();

    await fb.FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: timeout,
      verificationCompleted: (fb.PhoneAuthCredential cred) async {
        // Intentionally not auto-signing-in; UI expects manual OTP entry.
      },
      verificationFailed: (fb.FirebaseAuthException e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Not an error; user can still enter code.
      },
    );

    return completer.future;
  }

  // ─────────────────────────────────────────────
  // Step 1 verify
  // ─────────────────────────────────────────────

  Future<void> verifyCode({required String code}) async {
    final c = code.trim();
    if (c.length != 6) {
      SnackService.showError('Enter 6-digit code');
      return;
    }
    if (!mounted || state.busy) return;

    state = state.copyWith(verifying: true, stepHint: 'Verifying…');

    try {
      final svc = await _auth();
      final attemptId = (state.attemptId ?? '').trim();

      // EMAIL path
      if (attemptId.isNotEmpty) {
        await svc.verifyOtpAndSignIn(attemptId: attemptId, code: c);

        if (!mounted) return;

        final next = await _postAuthNextStep(svc);
        if (!mounted) return;

        if (next == OtpNextStep.done) {
          _closeNow();
          return;
        }

        final step = _mapOtpNextToLoginStep(next);
        state = state.copyWith(
          step: step,
          attemptId: null,
          stepHint: _hintForStep(step),
        );
        return;
      }

      // SMS path (Firebase)
      if (kIsWeb) {
        final res = _webResult;
        if (res == null) throw StateError('Missing web confirmation result');
        await res.confirm(c);
      } else {
        final vid = (_mobileVerificationId ?? '').trim();
        if (vid.isEmpty) throw StateError('Missing verificationId');

        final cred = fb.PhoneAuthProvider.credential(
          verificationId: vid,
          smsCode: c,
        );
        await fb.FirebaseAuth.instance.signInWithCredential(cred);
      }

      _resetFirebaseOtpState();

      final next = await _postAuthNextStep(svc);
      if (!mounted) return;

      if (next == OtpNextStep.done) {
        _closeNow();
        return;
      }

      final step = _mapOtpNextToLoginStep(next);
      state = state.copyWith(step: step, stepHint: _hintForStep(step));
    } catch (err) {
      SnackService.showError('Could not verify code. Try again.');
      if (kDebugMode) debugPrint('⚠️ [login] verify failed: $err');
      if (!mounted) return;

      state = state.copyWith(stepHint: _hintForStep(LoginStep.otp));
    } finally {
      if (!mounted) return;
      state = state.copyWith(verifying: false);
    }
  }

  void setPhoneNumber(String phoneE164) {
    final p = phoneE164.trim();
    if (p.isEmpty) return;

    _lastPhoneE164 = p;

    if (!mounted) return;
    state = state.copyWith(phoneNumber: p);
  }

  // ─────────────────────────────────────────────
  // Step 2: email verify
  // ─────────────────────────────────────────────

  Future<void> startEmailVerify({required String email}) async {
    final e = email.trim();
    if (!_looksLikeEmail(e)) {
      SnackService.showError('Enter a valid email');
      return;
    }

    if (!mounted || state.busy) return;

    state = state.copyWith(sending: true, stepHint: 'Sending email code…');

    try {
      final svc = await _auth();
      final fbUser = fb.FirebaseAuth.instance.currentUser;

      // ─────────────────────────────────────────────
      // PUBLIC: email login start (Somalia flow)
      // ─────────────────────────────────────────────
      if (fbUser == null) {
        // Robust phone binding:
        // 1) Riverpod state
        // 2) fallback to cached local phone
        final phone = (state.phoneNumber ?? '').trim().isNotEmpty
            ? state.phoneNumber!.trim()
            : (_lastPhoneE164 ?? '').trim();

        if (phone.isEmpty) {
          if (kDebugMode) {
            debugPrint('⚠️ [login] startEmailVerify: missing phone binding');
            debugPrint('   step=${state.step} sending=${state.sending}');
            debugPrint('   state.phoneNumber=${state.phoneNumber}');
            debugPrint('   _lastPhoneE164=$_lastPhoneE164');
          }

          SnackService.showError(
            'Missing phone number. Go back and enter your phone again.',
          );

          if (!mounted) return;
          state = state.copyWith(stepHint: _hintForStep(LoginStep.emailEntry));
          return;
        }

        final res = await svc.startEmailLoginOtp(
          email: e,
          phoneNumber: phone,
          codeLength: 6,
        );

        if (!mounted) return;

        if (res.throttled == true) {
          SnackService.showInfo('Please wait before requesting another code.');
          state = state.copyWith(stepHint: _hintForStep(LoginStep.emailEntry));
          return;
        }

        final attemptId = (res.attemptId ?? '').trim();
        if (attemptId.isEmpty) {
          SnackService.showError('No email attempt was returned. Try again.');
          state = state.copyWith(stepHint: _hintForStep(LoginStep.emailEntry));
          return;
        }

        state = state.copyWith(
          step: LoginStep.otp,
          attemptId: attemptId,
          channel: 'email',
          maskedTo: (res.maskedTo ?? '').trim(),
          stepHint: _hintForStep(LoginStep.otp),
        );
        return;
      }

      // ─────────────────────────────────────────────
      // AUTH REQUIRED: verify-email start (signed in)
      // ─────────────────────────────────────────────
      await fbUser.getIdToken(true);

      final res = await svc.startVerifyEmailOtp(email: e, codeLength: 6);

      if (!mounted) return;

      if (res.throttled == true) {
        SnackService.showInfo('Please wait before requesting another code.');
        state = state.copyWith(stepHint: _hintForStep(state.step));
        return;
      }

      final attemptId = (res.attemptId ?? '').trim();
      if (attemptId.isEmpty) {
        SnackService.showInfo(
          'If eligible, an email code will be sent shortly.',
        );
        state = state.copyWith(stepHint: _hintForStep(state.step));
        return;
      }

      final where = (res.maskedTo ?? '').trim();
      state = state.copyWith(
        step: LoginStep.emailOtp,
        emailAttemptId: attemptId,
        emailMaskedTo: where,
        stepHint: where.isNotEmpty
            ? 'Enter the code sent to $where'
            : 'Enter the email code.',
      );
    } catch (err) {
      // ✅ Friendly UX errors
      if (err is AuthApiException) {
        final code = err.code.trim().toUpperCase();

        // Map special cases to better UX behavior.
        if (code == 'EMAIL_PHONE_MISMATCH') {
          SnackService.showError(
            'That email doesn’t match the phone number you entered. '
            'Go back and confirm your phone number, or try a different email.',
          );

          if (!mounted) return;
          // Optional: bounce them back to phone since that's the fix.
          state = state.copyWith(
            step: LoginStep.phone,
            stepHint: _hintForStep(LoginStep.phone),
          );
          return;
        }

        // Default typed error
        SnackService.showError(err.userMessage);

        if (kDebugMode) {
          debugPrint(
            '⚠️ [login] startEmailVerify AuthApiException '
            'code=${err.code} status=${err.statusCode} debug=${err.debugMessage ?? ''}',
          );
        }
        return;
      }

      // Fallback: unexpected errors
      SnackService.showError('Could not send email code. Try again.');
      if (kDebugMode) debugPrint('⚠️ [login] startEmailVerify failed: $err');

      if (!mounted) return;
      state = state.copyWith(stepHint: _hintForStep(state.step));
    } finally {
      if (!mounted) return;
      state = state.copyWith(sending: false);
    }
  }

  Future<void> verifyEmailCode({required String code}) async {
    final c = code.trim();
    if (c.length != 6) {
      SnackService.showError('Enter 6-digit code');
      return;
    }

    final attemptId = (state.emailAttemptId ?? '').trim();
    if (attemptId.isEmpty) {
      SnackService.showError(
        'No email verification attempt. Request a new code.',
      );
      return;
    }

    if (!mounted || state.busy) return;

    state = state.copyWith(verifying: true, stepHint: 'Verifying…');

    try {
      final svc = await _auth();

      final out = await svc.verifyEmailOtpAuthed(attemptId: attemptId, code: c);

      final token = (out.customToken ?? '').trim();
      if (token.isEmpty) {
        SnackService.showError('Could not sign in (missing token).');
        return;
      }

      await svc.signInWithCustomToken(token);

      final next = await _postAuthNextStep(svc);
      if (!mounted) return;

      if (next == OtpNextStep.done) {
        state = LoginState.initial().copyWith(
          closeScreen: true,
          emailAttemptId: null,
          emailMaskedTo: null,
        );
        return;
      }

      final step = _mapOtpNextToLoginStep(next);
      state = state.copyWith(
        step: step,
        emailAttemptId: null,
        emailMaskedTo: null,
        stepHint: _hintForStep(step),
      );
    } catch (err) {
      SnackService.showError('Could not verify email code');
      if (kDebugMode) debugPrint('⚠️ [login] verifyEmailCode failed: $err');
    } finally {
      if (!mounted) return;
      state = state.copyWith(verifying: false);
    }
  }

  // ─────────────────────────────────────────────
  // Step 3: collect name => persist profile (now includes displayName)
  // ─────────────────────────────────────────────

  Future<void> finishOnboardingAfterName({
    required String firstName,
    required String lastName,
    required String displayName,
    String? companyName,
  }) async {
    final dn = displayName.trim();
    if (dn.isEmpty) {
      SnackService.showError('Display name is required');
      return;
    }

    final fnIn = firstName.trim();
    final lnIn = lastName.trim();
    final cn = (companyName ?? '').trim();

    final user = _ref.read(sessionControllerProvider(_tenantId)).valueOrNull;
    final isCompany = user?.isCompany == true;

    // Controller remains authority on business rules.
    if (isCompany) {
      if (cn.isEmpty) {
        SnackService.showError('Enter company name');
        return;
      }
    }

    // If first/last missing, derive from display name so backend always gets something.
    final derived = _deriveNamesFromDisplayName(dn);
    final fn = fnIn.isNotEmpty ? fnIn : derived.firstName;
    final ln = lnIn.isNotEmpty ? lnIn : derived.lastName;

    if (!isCompany) {
      // Keep your existing requirement: first+last must exist for individuals.
      // We satisfy it via derivation above.
      if (fn.trim().isEmpty || ln.trim().isEmpty) {
        SnackService.showError('Enter first and last name');
        return;
      }
    }

    if (!mounted || state.busy) return;

    state = state.copyWith(savingProfile: true, stepHint: 'Saving…');

    try {
      final svc = await _auth();

      await svc.saveProfile(
        firstName: fn.isEmpty ? '-' : fn,
        lastName: ln.isEmpty ? '-' : ln,
        displayName: dn,
        companyName: cn.isEmpty ? null : cn,
      );

      final next = await _postAuthNextStep(svc);
      if (!mounted) return;

      if (next == OtpNextStep.done) {
        _closeNow();
        return;
      }

      final step = _mapOtpNextToLoginStep(next);
      state = state.copyWith(step: step, stepHint: _hintForStep(step));
    } catch (err) {
      SnackService.showError('Could not save your profile');
      if (kDebugMode) debugPrint('⚠️ [login] saveProfile failed: $err');
    } finally {
      if (!mounted) return;
      state = state.copyWith(savingProfile: false);
    }
  }

  void forceStep(LoginStep step, {String? hint}) {
    if (!mounted) return;
    state = state.copyWith(step: step, stepHint: hint ?? _hintForStep(step));
  }
}
