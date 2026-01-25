import 'package:afyakit/core/auth/controllers/session_controller.dart';
import 'package:afyakit/core/auth/widgets/login_screen.dart';
import 'package:afyakit/core/auth_user/extensions/user_type_x.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/core/auth_user/providers/current_user_providers.dart';
import 'package:afyakit/core/tenancy/models/feature_keys.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/tenancy/widgets/feature_gate.dart';
import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';
import 'package:afyakit/features/home/models/home_mode.dart';
import 'package:afyakit/features/home/providers/home_mode_provider.dart';
import 'package:afyakit/features/home/widgets/common/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TenantHomeShell extends ConsumerWidget {
  const TenantHomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final uiMode = ref.watch(homeModeProvider);

    return userAsync.when(
      loading: () => _buildLoading(),
      error: (err, st) => _buildError(context, ref, err),
      data: (user) => _buildData(context, ref, user, uiMode),
    );
  }

  Widget _buildLoading() {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object err) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('❌ Failed to load user'),
              const SizedBox(height: 8),
              Text(err.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 14),
              _buildErrorActions(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorActions(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final tenantId = ref.read(tenantSlugProvider);
            await ref
                .read(sessionControllerProvider(tenantId).notifier)
                .logOut();
          },
          icon: const Icon(Icons.person_outline),
          label: const Text('Continue as guest'),
        ),
        FilledButton.icon(
          onPressed: () {
            final tenantId = ref.read(tenantSlugProvider);
            ref.read(sessionControllerProvider(tenantId).notifier).init();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
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
    AuthUser? user,
    HomeMode uiMode,
  ) {
    debugPrint(
      'TenantHomeShell: uiMode=$uiMode user=${user?.uid ?? "null"} type=${user?.type}',
    );

    if (user == null) return _buildGuest();

    if (!user.type.isStaff) return _buildMember(user);

    return _buildStaff(user, uiMode);
  }

  Widget _buildGuest() {
    return const FeatureGate(
      featureKey: FeatureKeys.retail,
      fallback: LoginScreen(),
      child: CatalogScreen(),
    );
  }

  Widget _buildMember(AuthUser user) {
    return HomeScreen(mode: HomeMode.member, user: user);
  }

  Widget _buildStaff(AuthUser user, HomeMode uiMode) {
    // ✅ If staff tries to go to Member mode, allow it only when retail is enabled.
    if (uiMode == HomeMode.member) {
      return FeatureGate(
        featureKey: FeatureKeys.retail,
        fallback: HomeScreen(mode: HomeMode.staff, user: user),
        child: HomeScreen(mode: HomeMode.member, user: user),
      );
    }

    // Default / normal staff view
    return HomeScreen(mode: uiMode, user: user);
  }
}
