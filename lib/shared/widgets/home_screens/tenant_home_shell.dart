// lib/shared/widgets/home_screens/tenant_home_shell.dart

import 'package:afyakit/core/tenancy/models/feature_keys.dart';
import 'package:afyakit/core/tenancy/providers/tenant_feature_providers.dart';
import 'package:afyakit/core/tenancy/widgets/feature_gate.dart';
import 'package:afyakit/core/auth_user/extensions/user_type_x.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/core/auth_user/providers/current_user_providers.dart';
import 'package:afyakit/core/auth/widgets/login_screen.dart';
import 'package:afyakit/modules/retail/catalog/widgets/screens/catalog_screen.dart';
import 'package:afyakit/shared/providers/home_view_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'member/member_home_screen.dart';
import 'staff/staff_home_screen.dart';

class TenantHomeShell extends ConsumerWidget {
  const TenantHomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final viewMode = ref.watch(homeViewModeProvider);

    // ✅ Single source of truth for feature booleans.
    // Your tenant_feature_providers.dart should compute these from tenantProfileProvider
    // and return safe defaults (false) while loading/error.
    final retailEnabled = ref.watch(tenantRetailEnabledProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) =>
          const Scaffold(body: Center(child: Text('❌ Failed to load user'))),
      data: (AuthUser? user) {
        // ────────────── GUEST MODE ──────────────
        if (user == null) {
          return const FeatureGate(
            featureKey: FeatureKeys.retailCatalog,
            fallback: LoginScreen(),
            child: CatalogScreen(),
          );
        }

        // ────────────── MEMBER-ONLY USERS ──────────────
        if (!user.type.isStaff) {
          return MemberHomeScreen(user: user);
        }

        // ────────────── STAFF USERS ──────────────
        // Retail disabled for this tenant → no toggle, always staff home.
        if (!retailEnabled) {
          return StaffHomeScreen(user: user);
        }

        // Retail enabled → allow staff/member toggle.
        return viewMode == HomeViewMode.staff
            ? StaffHomeScreen(user: user)
            : MemberHomeScreen(user: user);
      },
    );
  }
}
