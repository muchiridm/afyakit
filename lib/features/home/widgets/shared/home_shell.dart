import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/app_identity.dart';
import 'package:afyakit/app/providers/app_profile_providers.dart';

import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/auth_session/models/otp_login_copy.dart';
import 'package:afyakit/core/auth/auth_session/widgets/login_screen.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

import 'package:afyakit/core/capabilities/feature_keys.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

import 'package:afyakit/features/home/enums/entry_mode.dart';
import 'package:afyakit/features/home/providers/entry_mode_providers.dart';
import 'package:afyakit/features/home/widgets/guest/guest_health_landing.dart';
import 'package:afyakit/features/home/widgets/shared/home_dashboard/home_screen.dart';

import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  // ─────────────────────────────────────────
  // Entry mode
  // ─────────────────────────────────────────

  EntryMode _entryModeFor(AuthUser? user) {
    if (user == null) {
      return EntryMode.guest;
    }

    return user.isStaffResolved ? EntryMode.staff : EntryMode.member;
  }

  // ─────────────────────────────────────────
  // Login navigation
  // ─────────────────────────────────────────

  Widget _loginScreen(String appName) {
    return LoginScreen(copy: OtpLoginCopy.tenant(tenantName: appName));
  }

  void _openLogin(BuildContext context, String appName) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _loginScreen(appName),
        fullscreenDialog: true,
      ),
    );
  }

  // ─────────────────────────────────────────
  // Loading
  // ─────────────────────────────────────────

  Widget _loadingScreen() {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  // ─────────────────────────────────────────
  // Guest experience
  // ─────────────────────────────────────────

  Widget _guestHome(BuildContext context, WidgetRef ref) {
    final appProfileAsync = ref.watch(appProfileProvider);

    return appProfileAsync.when(
      loading: _loadingScreen,

      error: (error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Unable to load app configuration.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
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

        // Occupational Health is independent
        // of Clinical and uses shared Core Records.
        if (occupationalHealthEnabled) {
          return GuestHealthLanding(
            appName: appName,
            occupationalHealthEnabled: true,
            onGetStarted: () => _openLogin(context, appName),
          );
        }

        // Clinical healthcare experience.
        // Health Tracking is no longer a capability.
        if (clinicalEnabled) {
          return GuestHealthLanding(
            appName: appName,
            occupationalHealthEnabled: false,
            onGetStarted: () => _openLogin(context, appName),
          );
        }

        // Pharmacy application.
        // Clinical is not required for catalogue browsing.
        if (pharmacyEnabled) {
          return const CatalogScreen();
        }

        // Other applications require authentication.
        return _loginScreen(appName);
      },
    );
  }

  // ─────────────────────────────────────────
  // Application gate
  // ─────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);

    final sessionAsync = ref.watch(sessionControllerProvider(tenantId));

    return sessionAsync.when(
      loading: _loadingScreen,

      error: (error, _) =>
          _buildError(context, ref, tenantId, AppIdentity.appId, error),

      data: (user) {
        final realEntry = _entryModeFor(user);

        // Unauthenticated visitors receive the
        // app's capability-specific public experience.
        if (realEntry == EntryMode.guest) {
          return _guestHome(context, ref);
        }

        // Authenticated members use member mode.
        //
        // Staff may switch between staff and
        // member dashboards.
        final staffView = ref.watch(staffViewModeProvider);

        final effectiveEntry = switch (realEntry) {
          EntryMode.guest => EntryMode.guest,
          EntryMode.member => EntryMode.member,
          EntryMode.staff =>
            staffView == EntryMode.staff ? EntryMode.staff : EntryMode.member,
        };

        return HomeScreen(
          key: ValueKey<String>(
            'home-screen-'
            '${effectiveEntry.name}-'
            '${user?.contactId ?? 'unknown'}',
          ),
          realEntry: realEntry,
          effectiveEntry: effectiveEntry,
          user: user,
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // Session error
  // ─────────────────────────────────────────

  Widget _buildError(
    BuildContext context,
    WidgetRef ref,
    String tenantId,
    String appName,
    Object error,
  ) {
    Future<void> logOut() {
      return ref.read(sessionControllerProvider(tenantId).notifier).logOut();
    }

    Future<void> openLogin() async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _loginScreen(appName),
          fullscreenDialog: true,
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load session'),

              const SizedBox(height: 8),

              Text(error.toString(), textAlign: TextAlign.center),

              const SizedBox(height: 14),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: logOut,
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Continue as guest'),
                  ),

                  FilledButton.icon(
                    onPressed: logOut,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),

                  OutlinedButton.icon(
                    onPressed: openLogin,
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
