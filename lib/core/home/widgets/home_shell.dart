// lib/core/home/widgets/home_shell.dart

import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/auth_session/models/otp_login_copy.dart';
import 'package:afyakit/core/auth/auth_session/widgets/login_screen.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/providers/entry_mode_providers.dart';
import 'package:afyakit/core/home/widgets/home_screen.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_feature_providers.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_profile_providers.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  EntryMode _entryModeFor(AuthUser? user) {
    if (user == null) return EntryMode.guest;
    return user.isStaffResolved ? EntryMode.staff : EntryMode.member;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final tenantName = ref.watch(tenantDisplayNameProvider);

    // Guests:
    // - if retail enabled: show guest surface
    // - else: force login
    final retailEnabled = ref.watch(tenantRetailEnabledProvider);

    final sessionAsync = ref.watch(sessionControllerProvider(tenantId));

    return sessionAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => _buildError(context, ref, tenantId, tenantName, err),
      data: (user) {
        final realEntry = _entryModeFor(user);

        // Staff-only: allow "view as member"
        final staffView = ref.watch(staffViewModeProvider);

        var effectiveEntry = realEntry;
        if (realEntry == EntryMode.staff) {
          effectiveEntry = (staffView == EntryMode.member)
              ? EntryMode.member
              : EntryMode.staff;
        }

        if (realEntry == EntryMode.guest) {
          if (retailEnabled) return const CatalogScreen();
          return LoginScreen(copy: OtpLoginCopy.tenant(tenantName: tenantName));
        }

        return HomeScreen(
          realEntry: realEntry,
          effectiveEntry: effectiveEntry,
          user: user, // non-null here
        );
      },
    );
  }

  Widget _buildError(
    BuildContext context,
    WidgetRef ref,
    String tenantId,
    String tenantName,
    Object err,
  ) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('❌ Failed to load session'),
              const SizedBox(height: 8),
              Text(err.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref
                          .read(sessionControllerProvider(tenantId).notifier)
                          .logOut();
                    },
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Continue as guest'),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      await ref
                          .read(sessionControllerProvider(tenantId).notifier)
                          .logOut();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => LoginScreen(
                            copy: OtpLoginCopy.tenant(tenantName: tenantName),
                          ),
                          fullscreenDialog: true,
                        ),
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
