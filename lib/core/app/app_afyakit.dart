// lib/app/app_afyakit.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/app/app_navigator.dart';
import 'package:afyakit/core/tenancy/providers/tenant_profile_providers.dart';
import 'package:afyakit/core/branding/services/web_branding.dart';

import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/core/auth/widgets/auth_gate.dart';
import 'package:afyakit/shared/theme/app_theme_overrides.dart';

class AppAfyaKit extends ConsumerWidget {
  const AppAfyaKit({super.key});

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

        final baseTheme = ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: profile.primaryColor),
          useMaterial3: true,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        );

        return MaterialApp(
          title: profile.displayName,
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          scaffoldMessengerKey: SnackService.scaffoldMessengerKey,

          // ✅ Apply “Home curves” everywhere
          theme: applyHomeLook(baseTheme),

          // ✅ Auth gate
          home: const AuthGate(),

          // ✅ Web stabilization layer (fixes mouse_tracker assertion triggers)
          builder: (context, child) {
            Widget w = child ?? const SizedBox.shrink();

            if (kIsWeb) {
              // 1) Tooltips are implemented with overlays + mouse tracking on web.
              //    When combined with frequent rebuilds (Riverpod) they can trigger:
              //    mouse_tracker.dart assertion: !_debugDuringDeviceUpdate
              w = TooltipTheme(
                data: const TooltipThemeData(
                  waitDuration: Duration(days: 365), // effectively disables
                ),
                child: w,
              );

              // 2) Hover/splash/highlight can contribute to hover-driven churn.
              //    This is a safe, pragmatic web-only stability tweak.
              w = Theme(
                data: Theme.of(context).copyWith(
                  hoverColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: w,
              );
            }

            return w;
          },
        );
      },
    );
  }
}
