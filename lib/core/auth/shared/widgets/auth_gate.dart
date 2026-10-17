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

  Widget _login(String name) => LoginScreen(copy: OtpLoginCopy.tenant(tenantName: name));

  void _openLogin(BuildContext context, String name) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _login(name),
      fullscreenDialog: true,
    ));
  }

  void _prepareOnboarding(WidgetRef ref, AuthUser user, OnboardingNeed need) {
    switch (need) {
      case OnboardingNeed.phone:
        OnboardingGate.forceStep(ref, LoginStep.phone,
          hint: 'Verify your phone number first to continue.');
        break;
      case OnboardingNeed.email:
        OnboardingGate.forceStep(ref, LoginStep.emailEntry,
          hint: 'Add and verify your email for this application.');
        break;
      case OnboardingNeed.name:
        OnboardingGate.forceStep(ref, LoginStep.nameEntry,
          hint: 'Complete your Native Contact to finish setup.');
        break;
      case OnboardingNeed.linkContact:
        // No client-side identity claiming. A trusted recovery/provisioning
        // operation must resolve the link before onboarding can proceed.
        break;
      case OnboardingNeed.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final appId = ref.watch(appIdProvider);
    final session = ref.watch(sessionControllerProvider(tenantId));

    return session.when(
      loading: () => const SplashScreen(),
      error: (error, _) => Blocked(
        msg: 'We could not load your session.\nCheck your internet connection and try again.\n\nDetails: $error',
        showSignOut: true,
      ),
      data: (user) {
        if (user == null) return const HomeShell();
        if (!user.status.isActive) {
          return Blocked(
            msg: 'Your account is currently "${user.status.wire}".\nPlease contact an administrator.',
            showSignOut: true,
          );
        }
        final need = OnboardingGate.need(user);
        if (need == OnboardingNeed.linkContact) {
          return const Blocked(
            msg: 'Your Native Contact link needs verification. Contact support to complete trusted account recovery or provisioning.',
            showSignOut: true,
          );
        }
        if (need == OnboardingNeed.none) {
          return NotificationBootstrap(
            key: ValueKey<String>('notifications:${user.uid}:$tenantId:$appId'),
            user: user.forApp(appId), appId: appId,
            child: const HomeShell(),
          );
        }

        _prepareOnboarding(ref, user, need);
        final appProfile = ref.watch(appProfileProvider);
        return appProfile.when(
          loading: () => const SplashScreen(),
          error: (error, _) => Blocked(
            msg: 'We could not load the app configuration.\nDetails: $error',
            showSignOut: true,
          ),
          data: (profile) {
            final name = profile.displayName.trim().isNotEmpty
                ? profile.displayName.trim() : profile.id;
            final features = profile.features;
            if (features.enabled(FeatureKeys.occupationalHealth)) {
              return GuestHealthLanding(
                appName: name,
                occupationalHealthEnabled: true,
                onGetStarted: () => _openLogin(context, name),
              );
            }
            if (features.enabled(FeatureKeys.clinical)) {
              return GuestHealthLanding(
                appName: name,
                occupationalHealthEnabled: false,
                onGetStarted: () => _openLogin(context, name),
              );
            }
            if (features.enabled(FeatureKeys.pharmacy)) {
              return const CatalogScreen();
            }
            return _login(name);
          },
        );
      },
    );
  }
}
