import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/auth_session/models/otp_login_copy.dart';
import 'package:afyakit/core/auth/auth_session/widgets/login_screen.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/providers/staff_view_mode_provider.dart';
import 'package:afyakit/core/home/widgets/home_screen.dart';
import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_feature_providers.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_profile_providers.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  EntryMode _entryModeFor(AuthUser? user) {
    if (user == null) return EntryMode.guest;
    if (user.type.isStaff) return EntryMode.staff;
    return EntryMode.member;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final tenantName = ref.watch(tenantDisplayNameProvider);

    final sessionAsync = ref.watch(sessionControllerProvider(tenantId));

    // ✅ Retail controls whether guests are allowed to browse the guest surface
    // (catalog/search etc). If retail not enabled, guests must login.
    final retailEnabled = ref.watch(tenantRetailEnabledProvider);

    if (sessionAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return sessionAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => _buildError(context, ref, tenantId, tenantName, err),
      data: (user) {
        final realEntry = _entryModeFor(user);

        // ✅ Staff-only: allow "view as member" via badge toggle.
        // IMPORTANT: provider is NOT autoDispose, so it persists.
        final staffView = ref.watch(staffViewModeProvider);

        // Default: effective == real
        var effectiveEntry = realEntry;

        // Staff can only be staff-surface or member-surface (never guest)
        if (realEntry == EntryMode.staff) {
          effectiveEntry = (staffView == EntryMode.member)
              ? EntryMode.member
              : EntryMode.staff;
        }

        // Guests:
        // - if retail enabled: show guest surface
        // - else: force login
        if (realEntry == EntryMode.guest) {
          if (retailEnabled) {
            return const CatalogScreen();
          }
          return LoginScreen(copy: OtpLoginCopy.tenant(tenantName: tenantName));
        }

        // Members: always member surface
        if (realEntry == EntryMode.member) {
          return HomeScreen(
            realEntry: EntryMode.member,
            effectiveEntry: EntryMode.member,
            user: user,
          );
        }

        // Staff: staff surface OR member surface depending on toggle
        return HomeScreen(
          realEntry: EntryMode.staff,
          effectiveEntry: effectiveEntry,
          user: user,
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
                      final ctrl = ref.read(
                        sessionControllerProvider(tenantId).notifier,
                      );
                      await ctrl.logOut();
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
