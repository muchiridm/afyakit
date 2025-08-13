import 'package:afyakit/users/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/users/screens/user_profile_editor_screen.dart';
import 'package:afyakit/shared/providers/users/combined_user_provider.dart';
import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/users/widgets/auth_gate.dart';

class InviteAcceptScreen extends ConsumerWidget {
  final Map<String, String> inviteParams;

  const InviteAcceptScreen({super.key, required this.inviteParams});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inviteUid = inviteParams['uid'];
    final combinedUser = ref.watch(combinedUserProvider);

    return combinedUser.when(
      loading: () =>
          const BaseScreen(body: Center(child: CircularProgressIndicator())),

      error: (error, _) =>
          BaseScreen(body: Center(child: Text('❌ Error loading user: $error'))),

      data: (user) {
        if (user == null) {
          return BaseScreen(
            body: Center(
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.mail_outline_rounded,
                          size: 52,
                          color: Color(0xFF1565C0), // Light Blue
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Welcome to DanabTMC Portal',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0), // Light Blue
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
                            backgroundColor: Color(0xFF1565C0), // Light Blue
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
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
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

        if (inviteUid != null && user.uid != inviteUid) {
          // 🔐 Wrong account
          return BaseScreen(
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
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  child: const Text('Go to Home'),
                ),
              ],
            ),
          );
        }

        final isInvited = user.status.name == 'invited';
        final profileIncomplete = user.displayName.trim().isEmpty;

        if (isInvited || profileIncomplete) {
          // 👋 Complete profile
          final tenantId = user.tenantId;

          return BaseScreen(
            body: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '👋 Welcome to DanabTMC!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
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

        // ✅ Already onboarded — proceed to AuthGate
        Future.microtask(() {
          if (context.mounted) {
            debugPrint('🔁 InviteAcceptScreen: redirecting to AuthGate...');
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => AuthGate(inviteParams: inviteParams),
              ),
              (_) => false,
            );
          }
        });

        return const BaseScreen(
          body: Center(child: Text('✅ Redirecting to app...')),
        );
      },
    );
  }
}
