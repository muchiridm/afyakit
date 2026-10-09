// lib/core/auth/shared/widgets/auth_gate.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/providers/app_profile_providers.dart';

import 'package:afyakit/core/auth/auth_session/controllers/login_controller.dart';
import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/auth_session/models/otp_login_copy.dart';
import 'package:afyakit/core/auth/auth_session/widgets/blocked.dart';
import 'package:afyakit/core/auth/auth_session/widgets/login_screen.dart';
import 'package:afyakit/core/auth/auth_user/widgets/screens/splash_screen.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/shared/widgets/onboarding_gate.dart';

import 'package:afyakit/core/capabilities/feature_keys.dart';

import 'package:afyakit/core/notifications/notification_bootstrap.dart';

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
              : 'Add your name. '
                    'We’ll use it to complete your account.',
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

    // The currently selected application.
    // No hard-coded app identifiers.
    final appId = ref.watch(appIdProvider);

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
        // 1. Unauthenticated visitors.
        //
        // HomeShell selects the appropriate
        // guest experience for the active app.

        if (user == null) {
          return const HomeShell();
        }

        // 2. Account restrictions.
        //
        // Inactive accounts cannot enter the
        // authenticated application.

        if (!_isActive(user)) {
          return Blocked(
            msg:
                'Your account is currently '
                '"${_statusLabel(user)}".\n'
                'Please contact an admin to activate your access.',
            showSignOut: true,
          );
        }

        // 3. Onboarding requirements.
        //
        // The backend session determines
        // verification and account completeness.

        final need = OnboardingGate.need(user);

        // Fully onboarded users enter the
        // authenticated application.

        if (need == OnboardingNeed.none) {
          // Resolve staff roles for the active app.
          //
          // This does not substitute for server-side
          // app-membership authorisation.
          user.forApp(appId);

          return NotificationBootstrap(
            key: ValueKey<String>('notifications:${user.uid}:$tenantId:$appId'),
            user: user.forApp(appId),
            appId: appId,
            child: const HomeShell(),
          );
        }

        // Preserve the required onboarding step.
        _prepareOnboarding(ref, user, need);

        // ─────────────────────────────────────
        // Application-specific guest experience
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

            final occupationalHealthEnabled = features.enabled(
              FeatureKeys.occupationalHealth,
            );

            final clinicalEnabled = features.enabled(FeatureKeys.clinical);

            final pharmacyEnabled = features.enabled(FeatureKeys.pharmacy);

            // 4. Occupational Health.
            //
            // OccHealth is independent of Clinical.
            // Core Records are available by default.

            if (occupationalHealthEnabled) {
              return GuestHealthLanding(
                appName: appName,
                occupationalHealthEnabled: true,
                onGetStarted: () => _openLogin(context, appName),
              );
            }

            // 5. Clinical.
            //
            // AfyaTracker-style healthcare
            // experience.

            if (clinicalEnabled) {
              return GuestHealthLanding(
                appName: appName,
                occupationalHealthEnabled: false,
                onGetStarted: () => _openLogin(context, appName),
              );
            }

            // 6. Pharmacy.
            //
            // DawaPap provides catalogue browsing
            // without requiring Clinical.
            //
            // Pending onboarding remains enforced.

            if (pharmacyEnabled) {
              return const CatalogScreen();
            }

            // 7. Other applications.
            //
            // Continue onboarding directly if
            // no public landing is configured.

            return _login(appName);
          },
        );
      },
    );
  }
}
