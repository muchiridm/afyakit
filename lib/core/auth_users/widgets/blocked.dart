import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';

class Blocked extends StatelessWidget {
  const Blocked({required this.msg, this.showSignOut = false});
  final String msg;
  final bool showSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 48),
                const SizedBox(height: 12),
                Text(msg, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('OK'),
                    ),
                    if (showSignOut)
                      OutlinedButton.icon(
                        onPressed: () async {
                          await fb.FirebaseAuth.instance.signOut();
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
