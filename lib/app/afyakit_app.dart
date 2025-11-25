// lib/app/afyakit_app.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/hq/tenants/providers/tenant_profile_providers.dart';
import 'package:afyakit/hq/tenants/services/web_branding.dart';

import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/core/auth_users/widgets/auth_gate.dart';
import 'package:afyakit/core/auth_users/widgets/screens/invite_accept_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AfyaKitApp extends ConsumerWidget {
  final bool isInviteFlow;
  final Map<String, String>? inviteParams;

  const AfyaKitApp({super.key, required this.isInviteFlow, this.inviteParams});

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

        // decide first screen
        final Widget root = isInviteFlow
            ? ((inviteParams == null || inviteParams!.isEmpty)
                  ? const _BadInviteScreen()
                  : InviteAcceptScreen(inviteParams: inviteParams!))
            : const AuthGate(); // <- your existing auth gate

        return MaterialApp(
          // This is the logical app title for platforms; DOM title is set above
          title: profile.displayName,
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: SnackService.scaffoldMessengerKey,
          home: root,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: profile.primaryColor),
            useMaterial3: true,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
        );
      },
    );
  }
}

class _BadInviteScreen extends StatelessWidget {
  const _BadInviteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.link_off, size: 56),
              const SizedBox(height: 12),
              const Text(
                'Invalid or incomplete invite link.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please request a fresh invite or try opening the link again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
