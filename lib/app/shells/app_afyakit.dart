// lib/app/shells/app_afyakit.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/app_navigator.dart';
import 'package:afyakit/app/providers/app_profile_provider.dart';
import 'package:afyakit/core/auth/shared/widgets/auth_gate.dart';
import 'package:afyakit/core/branding/services/web_branding.dart';
import 'package:afyakit/core/tenancy/providers/tenant_profile_providers.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/theme/app_theme_overrides.dart';

class AppAfyaKit extends ConsumerWidget {
  const AppAfyaKit({super.key});

  static const String _bootTitle = 'Loading…';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(tenantProfileProvider);

    final appAsync = ref.watch(appProfileProvider);

    return tenantAsync.when(
      loading: () => _loadingApp(),
      error: (error, _) => _errorApp('Failed to load tenant profile:\n$error'),
      data: (tenantProfile) {
        return appAsync.when(
          loading: () => _loadingApp(),
          error: (error, _) => _errorApp('Failed to load app profile:\n$error'),
          data: (appProfile) {
            final webTitle = appProfile.webTitle.trim().isNotEmpty
                ? appProfile.webTitle.trim()
                : appProfile.displayName.trim().isNotEmpty
                ? appProfile.displayName.trim()
                : appProfile.id;

            /*
             * Temporary:
             *
             * DOM branding is still tenant-based because web_branding.dart
             * currently accepts TenantProfile.
             *
             * The visual Flutter theme below is already app-based.
             *
             * Next step:
             * make web branding consume AppProfile so favicon, PWA icons,
             * metadata, and theme-color are app-specific too.
             */
            if (kIsWeb) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                applyAppBrandingToDom(appProfile);
              });
            }

            final baseTheme = ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: appProfile.primaryColor,
              ),
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
                Widget result = child ?? const SizedBox.shrink();

                result = Title(
                  title: webTitle,
                  color: appProfile.primaryColor,
                  child: result,
                );

                if (kIsWeb) {
                  result = TooltipTheme(
                    data: const TooltipThemeData(
                      waitDuration: Duration(days: 365),
                    ),
                    child: result,
                  );

                  result = Theme(
                    data: Theme.of(context).copyWith(
                      hoverColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: result,
                  );
                }

                return result;
              },
            );
          },
        );
      },
    );
  }

  MaterialApp _loadingApp() {
    return MaterialApp(
      title: _bootTitle,
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: SnackService.scaffoldMessengerKey,
      home: const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }

  MaterialApp _errorApp(String message) {
    return MaterialApp(
      title: _bootTitle,
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: SnackService.scaffoldMessengerKey,
      home: Scaffold(
        body: Center(child: Text(message, textAlign: TextAlign.center)),
      ),
    );
  }
}
