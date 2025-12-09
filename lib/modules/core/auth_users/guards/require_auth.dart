// lib/core/auth_users/guards/require_auth.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/modules/core/auth_users/providers/current_user_providers.dart';
import 'package:afyakit/modules/core/auth_users/widgets/screens/login_screen.dart';

/// Ensures the user is authenticated before continuing.
/// Returns true if authenticated, false if user cancels or fails login.
Future<bool> requireAuth(BuildContext context, WidgetRef ref) async {
  // 1) Fast path — already logged in
  final userAsync = ref.read(currentUserProvider);
  final user = userAsync.hasValue ? userAsync.value : null;
  if (user != null) return true;

  // 2) Push WhatsApp/login screen and trust its result.
  //
  // IMPORTANT: we deliberately do NOT touch `ref` after this `await` to avoid
  // "Cannot use ref after the widget was disposed" crashes when the caller
  // widget gets popped while the login flow is active.
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => const LoginScreen(),
      fullscreenDialog: true,
    ),
  );

  // If LoginScreen only returns `true` on successful auth, we can just use that.
  return ok == true;
}
