// lib/core/auth/widgets/auth_gate.dart

import 'package:afyakit/core/auth/auth_session/controllers/login_controller.dart';
import 'package:afyakit/core/auth/auth_session/models/otp_login_copy.dart';
import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/auth_session/widgets/login_screen.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/auth_user/widgets/screens/splash_screen.dart';
import 'package:afyakit/hq/tenants/providers/tenant_profile_providers.dart';
import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/hq/tenants/providers/tenant_feature_providers.dart';
import 'package:afyakit/core/home/widgets/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'blocked.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  bool _isActive(AuthUser user) => user.status.isActive;
  String _statusLabel(AuthUser user) => user.status.wire;

  bool _requiresPhone(AuthUser user) => user.phoneSatisfied != true;
  bool _requiresEmail(AuthUser user) => user.emailVerified != true;

  bool _requiresName(AuthUser user) {
    final isCompany = user.isCompany == true;

    if (isCompany) {
      final cn = (user.companyName ?? '').trim();
      return cn.isEmpty;
    }

    final fn = (user.firstName ?? '').trim();
    final ln = (user.lastName ?? '').trim();
    return fn.isEmpty || ln.isEmpty;
  }

  void _forceLoginStep(WidgetRef ref, LoginStep step, {String? hint}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = ref.read(loginControllerProvider.notifier);
      final st = ref.read(loginControllerProvider);

      if (st.busy) return;

      final inPhoneFlow =
          st.step == LoginStep.phone || st.step == LoginStep.otp;
      final inEmailFlow =
          st.step == LoginStep.emailEntry || st.step == LoginStep.emailOtp;
      final inNameFlow = st.step == LoginStep.nameEntry;

      if (step == LoginStep.phone && inPhoneFlow) return;
      if (step == LoginStep.emailEntry && inEmailFlow) return;
      if (step == LoginStep.nameEntry && inNameFlow) return;

      ctrl.forceStep(step, hint: hint);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantSlugProvider);
    final tenantName = ref.watch(tenantDisplayNameProvider);

    // ✅ Make guest routing depend on tenant features.
    // This provider is optimistic while tenant profile loads (loading => true),
    // so guests won't be blocked by bootstrap.
    ref.watch(tenantRetailEnabledProvider);

    final sessionAsync = ref.watch(sessionControllerProvider(tenantId));

    return sessionAsync.when(
      loading: () => const SplashScreen(),
      error: (err, _) => Blocked(
        msg:
            'We could not load your session for "$tenantId".\n'
            'Check your internet connection and try again.\n\n'
            'Details: $err',
        showSignOut: true,
      ),
      data: (user) {
        // ✅ Guest:
        // Retail ON => go to TenantHomeShell (it will render Catalog for guest)
        // Retail OFF => show login
        if (user == null) {
          return const HomeShell(); // shell will decide guest view
        }

        if (!_isActive(user)) {
          final status = _statusLabel(user);
          return Blocked(
            msg:
                'Your account is currently "$status" on "$tenantId".\n'
                'Please contact an admin to activate your access.',
            showSignOut: true,
          );
        }

        // ✅ STRICT GATING ORDER
        if (_requiresPhone(user)) {
          _forceLoginStep(
            ref,
            LoginStep.phone,
            hint: 'Verify your phone number first to continue.',
          );
          return LoginScreen(copy: OtpLoginCopy.tenant(tenantName: tenantName));
        }

        if (_requiresEmail(user)) {
          _forceLoginStep(
            ref,
            LoginStep.emailEntry,
            hint: 'Add your email. We’ll send a 6-digit code to confirm it.',
          );
          return LoginScreen(copy: OtpLoginCopy.tenant(tenantName: tenantName));
        }

        if (_requiresName(user)) {
          _forceLoginStep(
            ref,
            LoginStep.nameEntry,
            hint: user.isCompany == true
                ? 'Add your company name to finish setup.'
                : 'Add your name to finish setup.',
          );
          return LoginScreen(copy: OtpLoginCopy.tenant(tenantName: tenantName));
        }

        return const HomeShell();
      },
    );
  }
}
