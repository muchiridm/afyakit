import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/core/auth/auth_session/models/otp_login_copy.dart';
import 'package:afyakit/core/auth/auth_session/widgets/login_screen.dart';

import '../shell/hq_shell.dart';

class HqGate extends StatelessWidget {
  const HqGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<fb.User?>(
      stream: fb.FirebaseAuth.instance.idTokenChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = snap.data;

        // Not signed in → HQ OTP login (email OTP only)
        if (user == null) {
          return const LoginScreen(copy: OtpLoginCopy.hq);
        }

        // Signed in → verify superadmin with a fresh token
        return FutureBuilder<bool>(
          future: _hasSuperadmin(user),
          builder: (context, authSnap) {
            if (authSnap.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            if (authSnap.hasError) {
              return _ErrorScreen(
                message: 'Failed to verify permissions.\n${authSnap.error}',
                onSignOut: () => fb.FirebaseAuth.instance.signOut(),
              );
            }

            final allowed = authSnap.data == true;

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: allowed
                  ? const HqShell(key: ValueKey('hq-shell'))
                  : _NoAccessScreen(
                      key: const ValueKey('no-access'),
                      onSignOut: () => fb.FirebaseAuth.instance.signOut(),
                    ),
            );
          },
        );
      },
    );
  }

  // Log only when state changes to keep console readable
  static String? _lastLogKey;

  static Future<bool> _hasSuperadmin(fb.User user) async {
    // Fresh token to pull latest claims
    final t = await user.getIdTokenResult(true);
    final claims = t.claims ?? const <String, dynamic>{};

    // Accept both claim names for backward compatibility
    final isSuper =
        claims['isSuperAdmin'] == true || claims['superadmin'] == true;

    final key =
        '${user.uid}|$isSuper|${user.phoneNumber ?? ''}|${user.email ?? ''}';
    if (_lastLogKey != key) {
      _lastLogKey = key;
      debugPrint(
        '🔐 [HqGate] uid=${user.uid} '
        'phone=${user.phoneNumber} email=${user.email} '
        'isSuperAdmin=$isSuper',
      );
    }

    return isSuper;
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
