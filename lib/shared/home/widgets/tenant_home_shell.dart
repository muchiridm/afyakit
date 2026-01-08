import 'package:afyakit/core/auth/controllers/session_controller.dart';
import 'package:afyakit/core/auth/widgets/login_screen.dart';
import 'package:afyakit/core/auth_user/extensions/user_type_x.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/core/auth_user/providers/current_user_providers.dart';
import 'package:afyakit/core/tenancy/models/feature_keys.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/tenancy/widgets/feature_gate.dart';
import 'package:afyakit/features/retail/catalog/widgets/screens/catalog_screen.dart';
import 'package:afyakit/shared/home/models/home_mode.dart';
import 'package:afyakit/shared/home/widgets/common/home_screen.dart';
import 'package:afyakit/shared/home/providers/home_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TenantHomeShell extends ConsumerWidget {
  const TenantHomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    // Persisted UI mode (meaningful for staff who can switch views).
    final uiMode = ref.watch(homeModeProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, st) => Scaffold(
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
                Wrap(
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
                        ref
                            .read(sessionControllerProvider(tenantId).notifier)
                            .init();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (_) => false,
                        );
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Sign in'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

      data: (AuthUser? user) {
        debugPrint(
          'TenantHomeShell: uiMode=$uiMode user=${user?.uid ?? "null"} type=${user?.type}',
        );

        // ────────────── GUEST MODE ──────────────
        if (user == null) {
          return const FeatureGate(
            featureKey: FeatureKeys.retail,
            fallback: LoginScreen(),
            child: CatalogScreen(),
          );
        }

        // ────────────── MEMBER-ONLY USERS ──────────────
        if (!user.type.isStaff) {
          return HomeScreen(mode: HomeMode.member, user: user);
        }

        // ────────────── STAFF USERS ──────────────
        // ✅ Staff can ALWAYS switch between member and staff views.
        return HomeScreen(mode: uiMode, user: user);
      },
    );
  }
}
