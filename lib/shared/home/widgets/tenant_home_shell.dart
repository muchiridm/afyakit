import 'package:afyakit/core/auth/widgets/login_screen.dart';
import 'package:afyakit/core/auth_user/extensions/user_type_x.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/core/auth_user/providers/current_user_providers.dart';
import 'package:afyakit/core/tenancy/models/feature_keys.dart';
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
      error: (_, __) =>
          const Scaffold(body: Center(child: Text('❌ Failed to load user'))),
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
