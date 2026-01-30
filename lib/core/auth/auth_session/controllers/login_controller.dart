import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/auth_session/services/auth_service.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/shared/services/snack_service.dart';
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
  );

  LoginState copyWith({
    LoginStep? step,
    bool? sending,
    bool? verifying,
    bool? savingProfile,
    String? attemptId,
    String? channel,
    String? maskedTo,
    String? emailAttemptId,
    String? emailMaskedTo,
    bool? closeScreen,
    String? stepHint,
  }) {
    return LoginState(
      step: step ?? this.step,
      sending: sending ?? this.sending,
      verifying: verifying ?? this.verifying,
      savingProfile: savingProfile ?? this.savingProfile,
      attemptId: attemptId ?? this.attemptId,
      channel: channel ?? this.channel,
      maskedTo: maskedTo ?? this.maskedTo,
      emailAttemptId: emailAttemptId ?? this.emailAttemptId,
      emailMaskedTo: emailMaskedTo ?? this.emailMaskedTo,
      closeScreen: closeScreen ?? this.closeScreen,
      stepHint: stepHint ?? this.stepHint,
    );
  }

  bool get busy => sending || verifying || savingProfile;
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

  Future<AuthService> _auth() =>
      _ref.read(authServiceProvider(_tenantId).future);

  SessionController get _session =>
      _ref.read(sessionControllerProvider(_tenantId).notifier);

  // ─────────────────────────────────────────────
  // Session helpers (IMPORTANT)
  // ─────────────────────────────────────────────

  /// Always refresh and return the latest tenant session user.
  /// This prevents the "valueOrNull was null → we thought onboarding is done" bug.
  Future<AuthUser?> _refreshAndGetSessionUser() async {
    await _session.refresh(forceNetwork: true);

    // refresh() can kick off async work; wait until provider is no longer loading
    for (var i = 0; i < 25; i++) {
      final v = _ref.read(sessionControllerProvider(_tenantId));
      if (!v.isLoading) return v.valueOrNull;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    // fallback (best effort)
    final sessionValue = _ref.read(sessionControllerProvider(_tenantId));
    return sessionValue.valueOrNull;
  }

  /// Returns:
  /// - LoginStep.emailEntry if email missing OR not verified
  /// - LoginStep.nameEntry if name incomplete
  /// - null if onboarding is complete
  LoginStep? _deriveNextStepFromUser(AuthUser? user) {
    if (user == null) return null;

    // ✅ hard gate: email must be verified before proceeding
    if (user.emailVerified != true) return LoginStep.emailEntry;

    final isCompany = user.isCompany == true;

    final fn = (user.firstName ?? '').trim();
    final ln = (user.lastName ?? '').trim();
    final cn = (user.companyName ?? '').trim();

    final nameComplete = isCompany
        ? cn.isNotEmpty
        : (fn.isNotEmpty && ln.isNotEmpty);
    if (!nameComplete) return LoginStep.nameEntry;

    return null;
  }

  // ─────────────────────────────────────────────

  void reset() {
    if (!mounted) return;
    state = LoginState.initial().copyWith(
      stepHint: 'Enter your phone number to continue.',
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

  bool _looksLikeEmail(String s) {
    final v = s.trim();
    return v.isNotEmpty && v.contains('@') && v.contains('.');
  }

  String _prettyDestination({String? maskedTo, String? channel}) {
    final m = (maskedTo ?? '').trim();
    if (m.isNotEmpty) return m;
    final ch = (channel ?? '').trim();
    return ch.isNotEmpty ? ch : '';
  }

  // ─────────────────────────────────────────────
  // Step 1: phone => /otp/start (PUBLIC)
  // Backend chooses SMS vs Email OTP.
  // ─────────────────────────────────────────────

  Future<void> sendCode({required String phoneE164}) async {
    final phone = phoneE164.trim();
    if (phone.isEmpty) {
      SnackService.showError('Enter phone number in +2547… format');
      return;
    }

    if (!mounted) return;
    state = LoginState.initial().copyWith(
      sending: true,
      stepHint: 'Sending code…',
    );

    try {
      final svc = await _auth();
      final res = await svc.startAutoOtp(phone);

      if (res.throttled == true) {
        SnackService.showInfo('Please wait before requesting another code.');
        return;
      }

      if (res.ok != true) {
        SnackService.showError('Failed to send code');
        return;
      }

      final attemptId = (res.attemptId ?? '').trim();
      if (attemptId.isEmpty) {
        SnackService.showInfo('If eligible, a code will be sent shortly.');
        return;
      }

      if (!mounted) return;

      final dest = _prettyDestination(
        maskedTo: res.maskedTo,
        channel: res.channel,
      );

      state = state.copyWith(
        step: LoginStep.otp,
        attemptId: attemptId,
        channel: res.channel,
        maskedTo: res.maskedTo,
        stepHint: dest.isNotEmpty
            ? 'Enter the code sent to $dest'
            : 'Enter the 6-digit code',
      );
    } catch (_) {
      SnackService.showError('Failed to send code');
    } finally {
      if (!mounted) return;
      state = state.copyWith(sending: false);
    }
  }

  Future<void> resendLoginOtp() async {
    if (!mounted) return;
    state = LoginState.initial().copyWith(
      stepHint: 'Enter your phone number to continue.',
    );
  }

  // ─────────────────────────────────────────────
  // Step 1 verify: /otp/verify (PUBLIC)
  // Sign in first, THEN refresh session and decide next step from fresh user.
  // ─────────────────────────────────────────────

  Future<void> verifyCode({required String code}) async {
    final c = code.trim();
    if (c.length != 6) {
      SnackService.showError('Enter 6-digit code');
      return;
    }

    final attemptId = (state.attemptId ?? '').trim();
    if (attemptId.isEmpty) {
      SnackService.showError('No active OTP attempt. Request a new code.');
      return;
    }

    if (!mounted) return;
    state = state.copyWith(verifying: true, stepHint: 'Verifying…');

    try {
      final svc = await _auth();
      final out = await svc.verifyOtpRaw(attemptId: attemptId, code: c);

      final token = (out.customToken ?? '').trim();
      if (token.isEmpty) {
        SnackService.showError('Could not sign in (missing token).');
        return;
      }

      // ✅ Sign in first
      await _session.signInWithCustomToken(token);

      // ✅ THEN force refresh and read the real tenant session user
      final user = await _refreshAndGetSessionUser();

      if (!mounted) return;

      final nextStep = _deriveNextStepFromUser(user);

      if (nextStep == null) {
        state = LoginState.initial().copyWith(closeScreen: true);
        return;
      }

      state = state.copyWith(step: nextStep, stepHint: _hintForStep(nextStep));
    } catch (_) {
      SnackService.showError('Could not verify code');
    } finally {
      if (!mounted) return;
      state = state.copyWith(verifying: false);
    }
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
        return dest.isNotEmpty
            ? 'Enter the code sent to $dest'
            : 'Enter the 6-digit code.';
      case LoginStep.emailEntry:
        return 'Add your email. We’ll send a 6-digit code to confirm it.';
      case LoginStep.emailOtp:
        final where = (state.emailMaskedTo ?? '').trim();
        return where.isNotEmpty
            ? 'Enter the code sent to $where'
            : 'Enter the email code.';
      case LoginStep.nameEntry:
        return 'Add your name to finish setup.';
    }
  }

  // ─────────────────────────────────────────────
  // Step 2: collect email => start verify email OTP (AUTH REQUIRED)
  // ─────────────────────────────────────────────

  Future<void> startEmailVerify({required String email}) async {
    final e = email.trim();
    if (!_looksLikeEmail(e)) {
      SnackService.showError('Enter a valid email');
      return;
    }

    if (!mounted) return;
    state = state.copyWith(sending: true, stepHint: 'Sending email code…');

    try {
      final svc = await _auth();
      final res = await svc.startVerifyEmailOtp(email: e, codeLength: 6);

      if (res.throttled == true) {
        SnackService.showInfo('Please wait before requesting another code.');
        return;
      }

      final attemptId = (res.attemptId ?? '').trim();
      if (attemptId.isEmpty) {
        SnackService.showInfo(
          'If eligible, an email code will be sent shortly.',
        );
        return;
      }

      if (!mounted) return;

      final where = (res.maskedTo ?? '').trim();
      state = state.copyWith(
        step: LoginStep.emailOtp,
        emailAttemptId: attemptId,
        emailMaskedTo: res.maskedTo,
        stepHint: where.isNotEmpty
            ? 'Enter the code sent to $where'
            : 'Enter the email code.',
      );
    } catch (_) {
      SnackService.showError('Failed to send email code');
    } finally {
      if (!mounted) return;
      state = state.copyWith(sending: false);
    }
  }

  // ─────────────────────────────────────────────
  // Step 2 verify: verify email OTP via /otp/verify
  // After this, refresh session and decide next step from fresh user.
  // ─────────────────────────────────────────────

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

    if (!mounted) return;
    state = state.copyWith(verifying: true, stepHint: 'Verifying…');

    try {
      final svc = await _auth();
      final out = await svc.verifyOtpRaw(attemptId: attemptId, code: c);

      final token = (out.customToken ?? '').trim();
      if (token.isEmpty) {
        SnackService.showError('Could not sign in (missing token).');
        return;
      }

      // 1) Sign in / refresh token (backend may mint a fresh custom token)
      await _session.signInWithCustomToken(token);

      // 2) FORCE backend session reload (ignore cache)
      await _session.refresh(forceNetwork: true);

      // 3) Read the fresh session user
      final sessionValue = _ref.read(sessionControllerProvider(_tenantId));
      final user = sessionValue.valueOrNull;

      if (!mounted) return;

      final nextStep = _deriveNextStepFromUser(user);

      // Clear email attempt state (prevents weirdness if user returns)
      if (nextStep == null) {
        state = LoginState.initial().copyWith(
          closeScreen: true,
          emailAttemptId: null,
          emailMaskedTo: null,
        );
        return;
      }

      state = state.copyWith(
        step: nextStep,
        emailAttemptId: null,
        emailMaskedTo: null,
        stepHint: _hintForStep(nextStep),
      );
    } catch (err) {
      SnackService.showError('Could not verify email code');
      if (kDebugMode) {
        debugPrint('⚠️ [login] verifyEmailCode failed: $err');
      }
    } finally {
      if (!mounted) return;
      state = state.copyWith(verifying: false);
    }
  }

  // ─────────────────────────────────────────────
  // Step 3: collect name => persist profile
  // (Aligned with isCompany handling)
  // ─────────────────────────────────────────────

  Future<void> finishOnboardingAfterName({
    required String firstName,
    required String lastName,
    String? companyName,
  }) async {
    final fn = firstName.trim();
    final ln = lastName.trim();
    final cn = (companyName ?? '').trim();

    // Decide validation based on current tenant session (company vs individual)
    final user = _ref.read(sessionControllerProvider(_tenantId)).valueOrNull;
    final isCompany = user?.isCompany == true;

    if (isCompany) {
      if (cn.isEmpty) {
        SnackService.showError('Enter company name');
        return;
      }
    } else {
      if (fn.isEmpty || ln.isEmpty) {
        SnackService.showError('Enter first and last name');
        return;
      }
    }

    if (!mounted) return;
    state = state.copyWith(savingProfile: true, stepHint: 'Saving…');

    try {
      final svc = await _auth();

      await svc.saveProfile(
        firstName: fn.isEmpty ? '-' : fn,
        lastName: ln.isEmpty ? '-' : ln,
        companyName: cn.isEmpty ? null : cn,
      );

      final refreshed = await _refreshAndGetSessionUser();

      if (!mounted) return;

      final nextStep = _deriveNextStepFromUser(refreshed);
      if (nextStep == null) {
        state = LoginState.initial().copyWith(closeScreen: true);
        return;
      }

      state = state.copyWith(step: nextStep, stepHint: _hintForStep(nextStep));
    } catch (err) {
      SnackService.showError('Could not save your profile');
      if (kDebugMode) {
        debugPrint('⚠️ [login] saveProfile failed: $err');
      }
    } finally {
      if (!mounted) return;
      state = state.copyWith(savingProfile: false);
    }
  }

  // Manual override (kept)
  void forceStep(LoginStep step, {String? hint}) {
    if (!mounted) return;
    state = state.copyWith(step: step, stepHint: hint ?? _hintForStep(step));
  }
}
