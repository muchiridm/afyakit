// lib/app/afyakit_app.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/tenancy/providers/tenant_profile_providers.dart';
import 'package:afyakit/core/branding/services/web_branding.dart';

import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/core/auth/widgets/auth_gate.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AfyaKitApp extends ConsumerWidget {
  const AfyaKitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(tenantProfileProvider);

    return asyncProfile.when(
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: Text('Failed to load tenant profile:\n$e')),
        ),
      ),

      // ── tenant loaded: build real app
      data: (profile) {
        // 🔥 Update browser DOM (favicon, title, meta description, theme-color)
        applyTenantBrandingToDom(profile);

        return MaterialApp(
          // Logical app title; DOM title is set by applyTenantBrandingToDom.
          title: profile.displayName,
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: SnackService.scaffoldMessengerKey,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: profile.primaryColor),
            useMaterial3: true,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}
