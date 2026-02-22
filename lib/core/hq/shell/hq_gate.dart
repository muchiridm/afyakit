// lib/core/hq/shell/hq_gate.dart

import 'package:afyakit/core/auth/auth_session/controllers/login_controller.dart';
import 'package:afyakit/core/auth/shared/widgets/onboarding_gate.dart';
import 'package:afyakit/core/hq/shell/hq_shell.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/auth_session/models/otp_login_copy.dart';
import 'package:afyakit/core/auth/auth_session/widgets/login_screen.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

final hqSuperadminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final u = fb.FirebaseAuth.instance.currentUser;
  if (u == null) return false;

  final t = await u.getIdTokenResult(true);
  final claims = t.claims ?? const <String, dynamic>{};

  return claims['isSuperAdmin'] == true;
});

class HqGate extends ConsumerWidget {
  const HqGate({super.key});

  bool _isActive(AuthUser user) => user.status.isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider); // HQ => "hq"
    final sessionAsync = ref.watch(sessionControllerProvider(tenantId));

    return sessionAsync.when(
      loading: () => const _LoadingScreen(),
      error: (err, _) => _ErrorScreen(
        message: 'Failed to load HQ session.\n$err',
        onSignOut: () async {
          await fb.FirebaseAuth.instance.signOut();
          ref.invalidate(sessionControllerProvider(tenantId));
        },
      ),
      data: (user) {
        if (user == null) {
          return const LoginScreen(copy: OtpLoginCopy.hq);
        }

        if (!_isActive(user)) {
          return _ErrorScreen(
            message:
                'Your account is currently "${user.status.wire}".\n'
                'Please contact an admin to activate HQ access.',
            onSignOut: () async {
              await fb.FirebaseAuth.instance.signOut();
              ref.invalidate(sessionControllerProvider(tenantId));
            },
          );
        }

        final need = OnboardingGate.need(user);

        if (need == OnboardingNeed.phone) {
          OnboardingGate.forceStep(
            ref,
            LoginStep.phone,
            hint: 'Verify your phone number first to continue.',
          );
          return const LoginScreen(copy: OtpLoginCopy.hq);
        }

        if (need == OnboardingNeed.email) {
          OnboardingGate.forceStep(
            ref,
            LoginStep.emailEntry,
            hint: user.hasEmail
                ? 'Verify your email. We’ll send a 6-digit code to confirm it.'
                : 'Add your email. We’ll send a 6-digit code to confirm it.',
          );
          return const LoginScreen(copy: OtpLoginCopy.hq);
        }

        if (need == OnboardingNeed.name) {
          OnboardingGate.forceStep(
            ref,
            LoginStep.nameEntry,
            hint: user.isCompany == true
                ? 'Add your company/profile details to finish setup.'
                : 'Add your profile details to finish setup.',
          );
          return const LoginScreen(copy: OtpLoginCopy.hq);
        }

        final allowed = ref.watch(hqSuperadminProvider);

        return allowed.when(
          loading: () => const _LoadingScreen(),
          error: (err, _) => _ErrorScreen(
            message: 'Failed to verify permissions.\n$err',
            onSignOut: () async {
              await fb.FirebaseAuth.instance.signOut();
              ref.invalidate(sessionControllerProvider(tenantId));
            },
          ),
          data: (ok) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: ok
                  ? const HqShell(key: ValueKey('hq-shell'))
                  : _NoAccessScreen(
                      key: const ValueKey('no-access'),
                      onSignOut: () async {
                        await fb.FirebaseAuth.instance.signOut();
                        ref.invalidate(sessionControllerProvider(tenantId));
                      },
                    ),
            );
          },
        );
      },
    );
  }
}

// ── Simple screens ───────────────────────────────────────────────────────────
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _NoAccessScreen extends StatelessWidget {
  final VoidCallback onSignOut;
  const _NoAccessScreen({super.key, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text('Superadmin access required.', style: t.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'This account is signed in, but it does not have HQ permissions.',
                  style: t.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onSignOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onSignOut;
  const _ErrorScreen({required this.message, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.orange, size: 48),
                const SizedBox(height: 12),
                Text('Something went wrong', style: t.titleMedium),
                const SizedBox(height: 6),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onSignOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
