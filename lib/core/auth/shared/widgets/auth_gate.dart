// lib/core/auth/shared/widgets/auth_gate.dart

import 'package:afyakit/core/auth/auth_session/controllers/login_controller.dart';
import 'package:afyakit/core/auth/auth_session/models/otp_login_copy.dart';
import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/auth_session/widgets/login_screen.dart';
import 'package:afyakit/core/auth/auth_user/widgets/screens/splash_screen.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/shared/widgets/onboarding_gate.dart';
import 'package:afyakit/core/home/widgets/home_shell.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_feature_providers.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_profile_providers.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth_session/widgets/blocked.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  bool _isActive(AuthUser user) => user.status.isActive;
  String _statusLabel(AuthUser user) => user.status.wire;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final tenantName = ref.watch(tenantDisplayNameProvider);

    // Guests depend on tenant features.
    ref.watch(tenantRetailEnabledProvider);

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
        if (user == null) return const HomeShell();

        if (!_isActive(user)) {
          final status = _statusLabel(user);
          return Blocked(
            msg:
                'Your account is currently "$status" on "$tenantId".\n'
                'Please contact an admin to activate your access.',
            showSignOut: true,
          );
        }

        // ✅ STRICT ONBOARDING ORDER (shared policy)
        final need = OnboardingGate.need(user);

        if (need == OnboardingNeed.phone) {
          OnboardingGate.forceStep(
            ref,
            LoginStep.phone,
            hint: 'Verify your phone number first to continue.',
          );
          return LoginScreen(copy: OtpLoginCopy.tenant(tenantName: tenantName));
        }

        if (need == OnboardingNeed.email) {
          OnboardingGate.forceStep(
            ref,
            LoginStep.emailEntry,
            hint: user.hasEmail
                ? 'Verify your email. We’ll send a 6-digit code to confirm it.'
                : 'Add your email. We’ll send a 6-digit code to confirm it.',
          );
          return LoginScreen(copy: OtpLoginCopy.tenant(tenantName: tenantName));
        }

        if (need == OnboardingNeed.name) {
          OnboardingGate.forceStep(
            ref,
            LoginStep.nameEntry,
            hint: user.isCompany == true
                ? 'Add your company name to finish setup.'
                : 'Add your name to finish setup.',
          );
          return LoginScreen(copy: OtpLoginCopy.tenant(tenantName: tenantName));
        }

        return const HomeShell();
      },
    );
  }
}
