// lib/shared/widgets/home_screens/tenant_home_shell.dart

import 'package:afyakit/modules/core/auth_users/extensions/user_type_x.dart';
import 'package:afyakit/modules/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/modules/core/auth_users/providers/current_user_providers.dart';
import 'package:afyakit/modules/core/auth_users/widgets/screens/login_screen.dart';
import 'package:afyakit/modules/retail/catalog/widgets/screens/catalog_screen.dart';
import 'package:afyakit/shared/providers/home_view_mode_provider.dart';
import 'package:afyakit/hq/tenants/widgets/feature_gate.dart';
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

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          const Scaffold(body: Center(child: Text('❌ Failed to load user'))),
      data: (AuthUser? user) {
        // ────────────── GUEST MODE ──────────────
        if (user == null) {
          return FeatureGate(
            feature: 'catalog',
            fallback: const LoginScreen(),
            child: const CatalogScreen(),
          );
        }

        // ────────────── MEMBER-ONLY USERS ──────────────
        if (!user.type.isStaff) {
          // force member view; ignore provider
          return MemberHomeScreen(user: user);
        }

        // ────────────── STAFF USERS WITH SWITCHER ──────────────
        return viewMode == HomeViewMode.staff
            ? StaffHomeScreen(user: user)
            : MemberHomeScreen(user: user);
      },
    );
  }
}
