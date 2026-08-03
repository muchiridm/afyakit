// lib/app/app_afyakit.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/app_navigator.dart';
import 'package:afyakit/core/auth/shared/widgets/auth_gate.dart';
import 'package:afyakit/core/hq/branding/services/web_branding.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_profile_providers.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/theme/app_theme_overrides.dart';

class AppAfyaKit extends ConsumerWidget {
  const AppAfyaKit({super.key});

  static const _bootTitle = 'Loading…';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(tenantProfileProvider);

    return asyncProfile.when(
      loading: () => MaterialApp(
        title: _bootTitle,
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        scaffoldMessengerKey: SnackService.scaffoldMessengerKey,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => MaterialApp(
        title: _bootTitle,
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        scaffoldMessengerKey: SnackService.scaffoldMessengerKey,
        home: Scaffold(
          body: Center(child: Text('Failed to load tenant profile:\n$e')),
        ),
      ),
      data: (profile) {
        final webTitle = profile.webTitle.trim().isNotEmpty
            ? profile.webTitle.trim()
            : profile.displayName.trim().isNotEmpty
            ? profile.displayName.trim()
            : profile.id;

        // Web side-effects: favicon/title/meta/theme-color.
        //
        // Do this after the frame instead of directly during build.
        if (kIsWeb) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            applyTenantBrandingToDom(profile);
          });
        }

        final baseTheme = ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: profile.primaryColor),
          useMaterial3: true,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        );

        return MaterialApp(
          title: webTitle,
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          scaffoldMessengerKey: SnackService.scaffoldMessengerKey,
          theme: applyHomeLook(baseTheme),
          home: const AuthGate(),
          builder: (context, child) {
            Widget w = child ?? const SizedBox.shrink();

            // Force the browser tab title from the tenant profile.
            w = Title(title: webTitle, color: profile.primaryColor, child: w);

            if (kIsWeb) {
              w = TooltipTheme(
                data: const TooltipThemeData(waitDuration: Duration(days: 365)),
                child: w,
              );

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
