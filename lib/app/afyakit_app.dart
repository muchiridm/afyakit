// lib/app/afyakit_app.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/app_navigator.dart';
import 'package:afyakit/core/tenancy/providers/tenant_profile_providers.dart';
import 'package:afyakit/core/branding/services/web_branding.dart';

import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/core/auth/widgets/auth_gate.dart';

class AfyaKitApp extends ConsumerWidget {
  const AfyaKitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(tenantProfileProvider);

    return asyncProfile.when(
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        scaffoldMessengerKey: SnackService.scaffoldMessengerKey,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        scaffoldMessengerKey: SnackService.scaffoldMessengerKey,
        home: Scaffold(
          body: Center(child: Text('Failed to load tenant profile:\n$e')),
        ),
      ),
      data: (profile) {
        // Web side-effects: favicon/title/meta/theme-color
        applyTenantBrandingToDom(profile);

        return MaterialApp(
          title: profile.displayName,
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
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
