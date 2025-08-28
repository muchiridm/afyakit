// lib/hq/screens/hq_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'hq_shell.dart';
import 'hq_login_screen.dart';

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
        if (user == null) {
          // not signed in → HQ login (Firebase-only)
          return const HqLoginScreen();
        }

        // signed in → check superadmin with fresh claims
        final future = _hasSuperadmin(user);
        return FutureBuilder<bool>(
          future: future,
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

  // throttle identical logs so the console stays readable
  static String? _lastLogKey;

  static Future<bool> _hasSuperadmin(fb.User user) async {
    final t = await user.getIdTokenResult(true); // get fresh claims
    final claims = t.claims ?? const <String, dynamic>{};
    final isSuper = claims['superadmin'] == true;
    final tenant = (claims['tenantId'] ?? claims['tenant'])?.toString();

    final key = '${user.uid}|$isSuper|$tenant';
    if (_lastLogKey != key) {
      _lastLogKey = key;
      debugPrint(
        '🔐 [HqGate] uid=${user.uid} email=${user.email} super=$isSuper tenant=$tenant',
      );
    }
    return isSuper;
  }
}

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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                'HQ access requires superadmin.',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              FilledButton(onPressed: onSignOut, child: const Text('Sign out')),
            ],
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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.orange, size: 48),
              const SizedBox(height: 12),
              Text('Something went wrong', style: textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onSignOut, child: const Text('Sign out')),
            ],
          ),
        ),
      ),
    );
  }
}
