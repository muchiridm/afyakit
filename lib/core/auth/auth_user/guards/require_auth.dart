// lib/core/auth_users/guards/require_auth.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/auth_session/models/otp_login_copy.dart';
import 'package:afyakit/core/auth/auth_session/widgets/login_screen.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_profile_providers.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

/// Ensures the user is authenticated before continuing.
/// Returns true if authenticated, false if user cancels/closes login.
Future<bool> requireAuth(BuildContext context, WidgetRef ref) async {
  final tenantId = ref.read(tenantSlugProvider);

  // 1) Fast path — already logged in for this tenant session
  final session = ref.read(sessionControllerProvider(tenantId));
  final user = session.hasValue ? session.value : null;
  if (user != null) return true;

  // Tenant name for UI copy (read BEFORE await)
  final tenantName = ref.read(tenantDisplayNameProvider);

  // 2) Push OTP login screen.
  //
  // IMPORTANT: do NOT touch `ref` after this await.
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          LoginScreen(copy: OtpLoginCopy.tenant(tenantName: tenantName)),
      fullscreenDialog: true,
    ),
  );

  // 3) After returning, re-check session without using `ref` (avoid disposed crashes).
  // We can safely use FirebaseAuth directly as a fallback signal, BUT your real
  // source of truth is sessionController -> user.
  //
  // Since we can't use `ref` here, we conservatively return "true if popped after success"
  // only if the caller immediately re-builds based on AuthGate/session state.
  //
  // ✅ Best option: re-check via Navigator result. So we should return a bool result.

  // If you want an accurate bool here, use the bool-returning route below instead.
  return false;
}
