// lib/core/auth_users/guards/require_auth.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/auth_session/models/otp_login_copy.dart';
import 'package:afyakit/core/auth/auth_session/widgets/login_screen.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

/// Ensures the user is authenticated before continuing.
///
/// Returns:
/// - true  → already authenticated, or login completed successfully
/// - false → login was cancelled/closed without success
Future<bool> requireAuth(BuildContext context, WidgetRef ref) async {
  final tenantId = ref.read(tenantIdProvider);

  // ─────────────────────────────────────────────
  // Fast path
  // ─────────────────────────────────────────────

  final session = ref.read(sessionControllerProvider(tenantId));

  final user = session.hasValue ? session.value : null;

  if (user != null) {
    return true;
  }

  // ─────────────────────────────────────────────
  // Product-facing login copy
  // ─────────────────────────────────────────────
  //
  // Tenant is backend infrastructure.
  // AppProfile owns the client-facing product name.

  final appProfile = ref.read(appProfileProvider);

  final appName = appProfile.maybeWhen(
    data: (profile) {
      final name = profile.displayName.trim();

      return name.isNotEmpty ? name : profile.id;
    },
    orElse: () => '',
  );

  // IMPORTANT:
  // Do not access `ref` after this await.
  final loggedIn = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) =>
          LoginScreen(copy: OtpLoginCopy.tenant(tenantName: appName)),
      fullscreenDialog: true,
    ),
  );

  return loggedIn == true;
}
