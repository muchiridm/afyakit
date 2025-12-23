// lib/core/auth_users/widgets/auth_gate.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/hq/tenants/providers/tenant_slug_provider.dart';
import 'package:afyakit/core/auth_users/controllers/session_controller.dart';
import 'package:afyakit/shared/widgets/splash_screen.dart';
import 'package:afyakit/shared/widgets/home_screen/home_screen.dart';
import 'package:afyakit/core/auth_users/widgets/screens/login_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tenantId = ref.read(tenantSlugProvider);
      ref.read(sessionControllerProvider(tenantId).notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tenantId = ref.watch(tenantSlugProvider);
    final sessionAsync = ref.watch(sessionControllerProvider(tenantId));

    return sessionAsync.when(
      loading: () => const SplashScreen(),
      error: (_, __) => const LoginScreen(),
      data: (user) {
        return const HomeScreen();
      },
    );
  }
}
