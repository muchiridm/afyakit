// lib/core/auth_users/guards/require_auth.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:afyakit/core/auth_users/providers/auth_session/current_user_providers.dart';
import 'package:afyakit/core/auth_users/screens/login_screen.dart';

/// Ensures the user is authenticated before continuing.
/// Returns true if the user is authenticated (now or after completing login).
Future<bool> requireAuth(BuildContext context, WidgetRef ref) async {
  // 1) Fast path: app user already present
  final appUserAsync = ref.read(currentUserProvider);
  final appUser = appUserAsync.hasValue ? appUserAsync.value : null;
  if (appUser != null) return true;

  // 2) Firebase has a user → let session catch up briefly (one frame)
  final fbUser = fb.FirebaseAuth.instance.currentUser;
  if (fbUser != null) {
    // Give the session a tick to hydrate (AuthGate/session controller will flip UI)
    await _nextFrame();
    final hydrated = ref.read(currentUserProvider).value != null;
    if (hydrated) return true;
    // Fall through to explicit login UI if still not hydrated (rare, but safe).
  }

  // 3) No session → present login UI on the LOCAL navigator (not root)
  bool? ok;
  try {
    // Option A: bottom sheet (recommended: doesn’t disturb root stack)
    ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: false, // 🔑 keep this off the root navigator
      isScrollControlled: true,
      builder: (_) => const _LoginSheetScaffold(child: LoginScreen()),
    );

    // Option B (if you prefer a full page): comment A, uncomment B
    // ok = await Navigator.of(context).push<bool>(
    //   MaterialPageRoute(
    //     builder: (_) => const LoginScreen(), // LoginScreen should return true on success
    //     fullscreenDialog: true,
    //   ),
    // );
  } catch (_) {
    // If the sheet fails to show for any reason, we’ll re-check below.
  }

  if (ok == true) return true;

  // 4) Re-check after the attempt: first Firebase, then app user with a short, bounded wait.
  if (fb.FirebaseAuth.instance.currentUser == null) return false;

  // Small bounded wait for app user hydration (up to ~250ms over a few frames).
  for (var i = 0; i < 5; i++) {
    final hydrated = ref.read(currentUserProvider).value != null;
    if (hydrated) return true;
    await _nextFrame();
  }
  // If Firebase is logged in but app user hasn’t hydrated yet, let the caller proceed if safe.
  // If your flows REQUIRE appUser, return false here instead.
  return true;
}

Future<void> _nextFrame() {
  final c = Completer<void>();
  SchedulerBinding.instance.addPostFrameCallback((_) => c.complete());
  return c.future;
}

/// Tiny wrapper that guarantees a Scaffold exists in the sheet
/// (prevents "no descendant Scaffolds" snackbar crashes).
class _LoginSheetScaffold extends StatelessWidget {
  final Widget child;
  const _LoginSheetScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(backgroundColor: Colors.transparent, body: child),
    );
  }
}
