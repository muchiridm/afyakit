// lib/core/auth/auth_session/widgets/auth_button.dart

import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/auth_session/widgets/auth_gate.dart';
import 'package:afyakit/core/auth/auth_user/guards/require_auth.dart';

/// A single button that handles:
/// - Login / Register (when guest)
/// - Logout (when authenticated)
///
/// Replaces the old LogoutButton.
class AuthButton extends ConsumerWidget {
  const AuthButton({
    super.key,
    this.loginLabel = 'Login',
    this.logoutLabel = 'Logout',
    this.dense = false,
  });

  final String loginLabel;
  final String logoutLabel;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantSlugProvider);
    final sessionAsync = ref.watch(sessionControllerProvider(tenantId));

    final user = sessionAsync.maybeWhen(data: (u) => u, orElse: () => null);

    final isLoggedIn = user != null;

    Future<void> doLogin() async {
      await requireAuth(context, ref);
    }

    Future<void> doLogout() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await ref.read(sessionControllerProvider(tenantId).notifier).logOut();

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    }

    final baseStyle = OutlinedButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

    // ─────────────────────────────────────────────
    // Dense (icon only)
    // ─────────────────────────────────────────────
    if (dense) {
      return Tooltip(
        message: isLoggedIn ? logoutLabel : loginLabel,
        child: OutlinedButton(
          style: baseStyle.copyWith(
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
          ),
          onPressed: isLoggedIn ? doLogout : doLogin,
          child: Icon(isLoggedIn ? Icons.logout : Icons.login, size: 18),
        ),
      );
    }

    // ─────────────────────────────────────────────
    // Normal (icon + label)
    // ─────────────────────────────────────────────
    return OutlinedButton.icon(
      icon: Icon(isLoggedIn ? Icons.logout : Icons.login, size: 18),
      label: Text(isLoggedIn ? logoutLabel : loginLabel),
      style: baseStyle.copyWith(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      ),
      onPressed: isLoggedIn ? doLogout : doLogin,
    );
  }
}
