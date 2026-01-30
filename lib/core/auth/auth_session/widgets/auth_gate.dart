// lib/core/auth/widgets/auth_gate.dart
import 'package:afyakit/core/auth/auth_session/controllers/login_controller.dart';
import 'package:afyakit/core/auth/auth_session/models/otp_login_copy.dart';
import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/auth_session/widgets/login_screen.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/auth_user/widgets/screens/splash_screen.dart';
import 'package:afyakit/core/tenancy/providers/tenant_profile_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/features/home/widgets/tenant_home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'blocked.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  bool _isActive(AuthUser user) => user.status.isActive;

  String _statusLabel(AuthUser user) => user.status.wire;

  bool _requiresEmail(AuthUser user) {
    // ✅ Don’t check user.email string (backend hides unverified email).
    return user.emailVerified != true;
  }

  bool _requiresName(AuthUser user) {
    final isCompany = user.isCompany == true;

    if (isCompany) {
      final cn = (user.companyName ?? '').trim();
      return cn.isEmpty;
    }

    final fn = (user.firstName ?? '').trim();
    final ln = (user.lastName ?? '').trim();
    return fn.isEmpty || ln.isEmpty;
  }

  void _forceLoginStep(WidgetRef ref, LoginStep step, {String? hint}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = ref.read(loginControllerProvider.notifier);
      final st = ref.read(loginControllerProvider);

      // ✅ If login flow is busy, don’t interfere.
      if (st.busy) return;

      // ✅ If user is already in the correct “area”, don’t reset them.
      // This is CRITICAL: AuthGate should not wipe attempts while user is verifying.
      final inEmailFlow =
          st.step == LoginStep.emailEntry || st.step == LoginStep.emailOtp;
      final inNameFlow = st.step == LoginStep.nameEntry;

      if (step == LoginStep.emailEntry && inEmailFlow) return;
      if (step == LoginStep.nameEntry && inNameFlow) return;

      // ✅ Don’t nuke state here. Just move to the required step.
      // reset() here was causing the “stuck at verify email” loop.
      ctrl.forceStep(step, hint: hint);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantSlugProvider);
    final tenantName = ref.watch(tenantDisplayNameProvider);

    final sessionAsync = ref.watch(sessionControllerProvider(tenantId));

    return sessionAsync.when(
      loading: () => const SplashScreen(),
      error: (err, _) => Blocked(
        msg:
            'We could not load your session for "$tenantId".\n'
            'Check your internet connection and try again.\n\n'
            'Details: $err',
        showSignOut: true,
      ),
      data: (user) {
        if (user == null) {
          return LoginScreen(copy: OtpLoginCopy.tenant(tenantName: tenantName));
        }

        if (!_isActive(user)) {
          final status = _statusLabel(user);
          return Blocked(
            msg:
                'Your account is currently "$status" on "$tenantId".\n'
                'Please contact an admin to activate your access.',
            showSignOut: true,
          );
        }

        // ✅ STRICT GATING:
        // Firebase signed-in is not enough. Must complete onboarding first.
        if (_requiresEmail(user)) {
          _forceLoginStep(
            ref,
            LoginStep.emailEntry,
            hint: 'Add your email. We’ll send a 6-digit code to confirm it.',
          );
          return LoginScreen(copy: OtpLoginCopy.tenant(tenantName: tenantName));
        }

        if (_requiresName(user)) {
          _forceLoginStep(
            ref,
            LoginStep.nameEntry,
            hint: user.isCompany == true
                ? 'Add your company name to finish setup.'
                : 'Add your name to finish setup.',
          );
          return LoginScreen(copy: OtpLoginCopy.tenant(tenantName: tenantName));
        }

        // ✅ Onboarding complete
        return const TenantHomeShell();
      },
    );
  }
}
