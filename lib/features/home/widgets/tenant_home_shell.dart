// lib/features/home/widgets/tenant_home_shell.dart

import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/auth_session/models/otp_login_copy.dart';
import 'package:afyakit/core/auth/auth_session/widgets/login_screen.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/tenancy/models/feature_keys.dart';
import 'package:afyakit/core/tenancy/providers/tenant_profile_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/tenancy/widgets/feature_gate.dart';
import 'package:afyakit/features/home/models/home_mode.dart';
import 'package:afyakit/features/home/providers/home_mode_provider.dart';
import 'package:afyakit/features/home/widgets/common/home_screen.dart';
import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TenantHomeShell extends ConsumerWidget {
  const TenantHomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantSlugProvider);
    final tenantName = ref.watch(tenantDisplayNameProvider);

    final sessionAsync = ref.watch(sessionControllerProvider(tenantId));
    final uiMode = ref.watch(homeModeProvider);

    return sessionAsync.when(
      loading: _buildLoading,
      error: (err, st) => _buildError(context, ref, tenantId, tenantName, err),
      data: (user) =>
          _buildData(context, ref, tenantId, tenantName, user, uiMode),
    );
  }

  Widget _buildLoading() {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Widget _buildError(
    BuildContext context,
    WidgetRef ref,
    String tenantId,
    String tenantName,
    Object err,
  ) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('❌ Failed to load session'),
              const SizedBox(height: 8),
              Text(err.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 14),
              _buildErrorActions(context, ref, tenantId, tenantName),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorActions(
    BuildContext context,
    WidgetRef ref,
    String tenantId,
    String tenantName,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            // "Continue as guest" == sign out -> session becomes null
            await ref
                .read(sessionControllerProvider(tenantId).notifier)
                .logOut();
          },
          icon: const Icon(Icons.person_outline),
          label: const Text('Continue as guest'),
        ),
        FilledButton.icon(
          onPressed: () async {
            final ctrl = ref.read(sessionControllerProvider(tenantId).notifier);
            await ctrl.logOut(); // clears state
            // auth listener will re-fire automatically
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),

        OutlinedButton.icon(
          onPressed: () async {
            // Open OTP login (no LoginScreen wrapper anymore)
            await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => LoginScreen(
                  copy: OtpLoginCopy.tenant(tenantName: tenantName),
                ),
                fullscreenDialog: true,
              ),
            );
          },
          icon: const Icon(Icons.login),
          label: const Text('Sign in'),
        ),
      ],
    );
  }

  Widget _buildData(
    BuildContext context,
    WidgetRef ref,
    String tenantId,
    String tenantName,
    AuthUser? user,
    HomeMode uiMode,
  ) {
    debugPrint(
      'TenantHomeShell: uiMode=$uiMode user=${user?.uid ?? "null"} type=${user?.type}',
    );

    // Guest flow
    if (user == null) return _buildGuest(tenantName);

    // Member flow
    if (!user.type.isStaff) return _buildMember(user);

    // Staff flow
    return _buildStaff(user, uiMode);
  }

  Widget _buildGuest(String tenantName) {
    // Retail enabled => show catalog
    // Retail disabled => show OTP login (simple, aligned)
    return FeatureGate(
      featureKey: FeatureKeys.retail,
      fallback: LoginScreen(copy: OtpLoginCopy.tenant(tenantName: tenantName)),
      child: const CatalogScreen(),
    );
  }

  Widget _buildMember(AuthUser user) {
    return HomeScreen(mode: HomeMode.member, user: user);
  }

  Widget _buildStaff(AuthUser user, HomeMode uiMode) {
    // If staff tries to go to Member mode, allow it only when retail is enabled.
    if (uiMode == HomeMode.member) {
      return FeatureGate(
        featureKey: FeatureKeys.retail,
        fallback: HomeScreen(mode: HomeMode.staff, user: user),
        child: HomeScreen(mode: HomeMode.member, user: user),
      );
    }

    return HomeScreen(mode: uiMode, user: user);
  }
}
