import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/providers/app_profile_provider.dart';

import 'package:afyakit/core/auth/auth_session/controllers/login_controller.dart';
import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/auth_session/models/otp_login_copy.dart';
import 'package:afyakit/core/auth/auth_session/widgets/blocked.dart';
import 'package:afyakit/core/auth/auth_session/widgets/login_screen.dart';
import 'package:afyakit/core/auth/auth_user/widgets/screens/splash_screen.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/shared/widgets/onboarding_gate.dart';

import 'package:afyakit/core/capabilities/feature_keys.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

import 'package:afyakit/features/home/widgets/guest/guest_health_landing.dart';
import 'package:afyakit/features/home/widgets/shared/home_shell.dart';
import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  // ─────────────────────────────────────────────
  // Account status
  // ─────────────────────────────────────────────

  bool _isActive(AuthUser user) => user.status.isActive;

  String _statusLabel(AuthUser user) => user.status.wire;

  // ─────────────────────────────────────────────
  // Login navigation
  // ─────────────────────────────────────────────

  Widget _login(String appName) {
    return LoginScreen(copy: OtpLoginCopy.tenant(tenantName: appName));
  }

  void _openLogin(BuildContext context, String appName) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _login(appName),
        fullscreenDialog: true,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Onboarding
  // ─────────────────────────────────────────────

  void _prepareOnboarding(WidgetRef ref, AuthUser user, OnboardingNeed need) {
    switch (need) {
      case OnboardingNeed.phone:
        OnboardingGate.forceStep(
          ref,
          LoginStep.phone,
          hint: 'Verify your phone number first to continue.',
        );

      case OnboardingNeed.email:
        OnboardingGate.forceStep(
          ref,
          LoginStep.emailEntry,
          hint: user.hasEmail
              ? 'Verify your email. '
                    'We’ll send a 6-digit code to confirm it.'
              : 'Add your email. '
                    'We’ll send a 6-digit code to confirm it.',
        );

      case OnboardingNeed.name:
        OnboardingGate.forceStep(
          ref,
          LoginStep.nameEntry,
          hint: user.isCompany == true
              ? 'Add your company name to finish setup.'
              : 'Add your name to finish setup.',
        );

      case OnboardingNeed.none:
        break;
    }
  }

  // ─────────────────────────────────────────────
  // Application gate
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);

    final sessionAsync = ref.watch(sessionControllerProvider(tenantId));

    return sessionAsync.when(
      // ─────────────────────────────────────────
      // Session loading
      // ─────────────────────────────────────────
      loading: () => const SplashScreen(),

      // ─────────────────────────────────────────
      // Session error
      // ─────────────────────────────────────────
      error: (error, _) => Blocked(
        msg:
            'We could not load your session.\n'
            'Check your internet connection and try again.\n\n'
            'Details: $error',
        showSignOut: true,
      ),

      // ─────────────────────────────────────────
      // Session available
      // ─────────────────────────────────────────
      data: (user) {
        // 1. Unauthenticated visitor.
        //
        // HomeShell selects the appropriate
        // guest experience for the current app.

        if (user == null) {
          return const HomeShell();
        }

        // 2. Account restrictions.
        //
        // Inactive accounts must not enter
        // the authenticated application or
        // bypass restrictions through public
        // landing pages.

        if (!_isActive(user)) {
          return Blocked(
            msg:
                'Your account is currently '
                '"${_statusLabel(user)}".\n'
                'Please contact an admin to activate your access.',
            showSignOut: true,
          );
        }

        // 3. Determine onboarding requirements.
        //
        // The backend session is the source
        // of truth for user verification
        // and profile completeness.

        final need = OnboardingGate.need(user);

        // ─────────────────────────────────────
        // Fully authenticated and onboarded
        // ─────────────────────────────────────
        //
        // IMPORTANT:
        //
        // A user who has completed onboarding
        // must enter the authenticated app.
        //
        // Do not route them through the
        // public catalogue or guest landing.
        //
        // This prevents the previous missing
        // transition from authenticated
        // session to member/staff experience.

        if (need == OnboardingNeed.none) {
          return const HomeShell();
        }

        // ─────────────────────────────────────
        // Incomplete onboarding
        // ─────────────────────────────────────
        //
        // Preserve the required next step.
        //
        // OnboardingGate.forceStep schedules
        // the state update after the frame
        // and avoids interrupting active
        // OTP/email verification flows.

        _prepareOnboarding(ref, user, need);

        // ─────────────────────────────────────
        // Application-specific public experience
        // ─────────────────────────────────────

        final appProfileAsync = ref.watch(appProfileProvider);

        return appProfileAsync.when(
          loading: () => const SplashScreen(),

          error: (error, _) => Blocked(
            msg:
                'We could not load the app configuration.\n'
                'Please try again.\n\n'
                'Details: $error',
            showSignOut: true,
          ),

          data: (profile) {
            final name = profile.displayName.trim();

            final appName = name.isNotEmpty ? name : profile.id;

            final features = profile.features;

            final pharmacyEnabled = features.enabled(FeatureKeys.pharmacy);

            final healthTrackingEnabled = features.enabled(
              FeatureKeys.healthTracking,
            );

            final occupationalHealthEnabled = features.enabled(
              FeatureKeys.occupationalHealth,
            );

            // 4. Pharmacy.
            //
            // Allow public catalogue browsing
            // without removing the pending
            // onboarding requirement.

            if (pharmacyEnabled) {
              return const CatalogScreen();
            }

            // 5. Health tracking.
            //
            // Occupational Health modifies
            // the guest experience when both
            // capabilities are enabled.

            if (healthTrackingEnabled) {
              return GuestHealthLanding(
                appName: appName,
                occupationalHealthEnabled: occupationalHealthEnabled,
                onGetStarted: () {
                  _openLogin(context, appName);
                },
              );
            }

            // 6. No public guest experience.
            //
            // Continue the required
            // onboarding step directly.

            return _login(appName);
          },
        );
      },
    );
  }
}
