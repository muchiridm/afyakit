// lib/shared/widgets/home_screen/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/widgets/screens/base_screen.dart';
import 'package:afyakit/shared/widgets/home_screens/home_action_buttons.dart';
import 'package:afyakit/shared/widgets/home_screens/home_header.dart';
import 'package:afyakit/shared/widgets/home_screens/latest_activity_panel.dart';

import 'package:afyakit/core/auth_users/providers/current_user_providers.dart';
import 'package:afyakit/core/catalog/widgets/screens/catalog_screen.dart';
import 'package:afyakit/core/auth_users/widgets/screens/login_screen.dart';
import 'package:afyakit/core/records/deliveries/controllers/delivery_session_controller.dart';

import 'package:afyakit/hq/tenants/widgets/feature_gate.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          const Scaffold(body: Center(child: Text('❌ Failed to load user'))),
      data: (user) {
        // ── GUEST: show catalog only if tenant has catalog, else show login screen
        if (user == null) {
          return FeatureGate(
            feature: 'catalog',
            // if catalog is NOT enabled → show login screen
            fallback: const LoginScreen(),
            child: const CatalogScreen(),
          );
        }

        // ── AUTH: your existing home layout
        ref.watch(deliverySessionControllerProvider);

        return BaseScreen(
          scrollable: true,
          maxContentWidth: 800,
          header: const HomeHeader(),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              LatestActivityPanel(),
              SizedBox(height: 32),
              HomeActionButtons(),
            ],
          ),
        );
      },
    );
  }
}
