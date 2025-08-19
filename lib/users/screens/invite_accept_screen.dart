import 'package:afyakit/users/user_manager/extensions/user_status_x.dart';
import 'package:afyakit/users/user_manager/extensions/auth_user_x.dart';
import 'package:afyakit/users/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/users/screens/user_profile_editor_screen.dart';
import 'package:afyakit/users/user_operations/providers/current_user_provider.dart';
import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/users/widgets/auth_gate.dart';
import 'package:afyakit/tenants/providers/tenant_config_provider.dart';

class InviteAcceptScreen extends ConsumerWidget {
  final Map<String, String> inviteParams;

  const InviteAcceptScreen({super.key, required this.inviteParams});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inviteUid = inviteParams['uid'];

    // theme + tenant
    final cfg = ref.watch(tenantConfigProvider);
    final displayName = cfg.displayName;
    final primary = Theme.of(context).colorScheme.primary;

    final asyncUser = ref.watch(
      currentUserProvider,
    ); // now AsyncValue<AuthUser?>

    return asyncUser.when(
      loading: () => _buildLoading(),
      error: (err, _) => _buildError(err),
      data: (user) {
        // Not signed in → show invite/login card
        if (user == null) {
          return _buildInviteCard(context, displayName, primary);
        }

        // Wrong account used with invite link
        if (inviteUid != null && user.uid != inviteUid) {
          return _buildWrongAccount(context);
        }

        // Use your status extension if you have it; otherwise compare string
        final isInvited =
            user.statusEnum.isInvited; // or: user.status == 'invited'
        final profileIncomplete = (user.displayName).trim().isEmpty;

        if (isInvited || profileIncomplete) {
          return _buildCompleteProfile(
            context: context,
            displayName: displayName,
            tenantId: user.tenantId,
          );
        }

        // Already onboarded → hop to AuthGate
        return _redirectToAuthGate(context, inviteParams);
      },
    );
  }

  // --- Private builders ------------------------------------------------------

  BaseScreen _buildLoading() =>
      const BaseScreen(body: Center(child: CircularProgressIndicator()));

  BaseScreen _buildError(Object error) =>
      BaseScreen(body: Center(child: Text('❌ Error loading user: $error')));

  BaseScreen _buildInviteCard(
    BuildContext context,
    String displayName,
    Color primary,
  ) {
    return BaseScreen(
      body: Center(
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mail_outline_rounded, size: 52, color: primary),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome to $displayName Portal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'To get started, sign in using your registered email address.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.lock_open_rounded, size: 20),
                    label: const Text(
                      'Set Your Password',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BaseScreen _buildWrongAccount(BuildContext context) => BaseScreen(
    body: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.block, size: 48, color: Colors.redAccent),
        const SizedBox(height: 16),
        const Text(
          '🚫 This invite link doesn’t match your account.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
          child: const Text('Go to Home'),
        ),
      ],
    ),
  );

  BaseScreen _buildCompleteProfile({
    required BuildContext context,
    required String displayName,
    required String tenantId,
  }) {
    return BaseScreen(
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '👋 Welcome to $displayName!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Let’s finish setting up your profile so you can get started.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Complete Profile'),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileEditorScreen(
                      tenantId: tenantId,
                      inviteParams: inviteParams,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Schedules navigation to AuthGate and shows a small placeholder instantly.
  BaseScreen _redirectToAuthGate(
    BuildContext context,
    Map<String, String> inviteParams,
  ) {
    Future.microtask(() {
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => AuthGate(inviteParams: inviteParams)),
        (_) => false,
      );
    });

    return const BaseScreen(
      body: Center(child: Text('✅ Redirecting to app...')),
    );
  }
}
