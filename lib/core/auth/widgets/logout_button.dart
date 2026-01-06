// lib/modules/core/auth_users/widgets/logout_button.dart

import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/controllers/session_controller.dart';
import 'package:afyakit/core/auth/widgets/auth_gate.dart';

class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key, this.label = 'Logout', this.dense = false});

  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> doLogout() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Logout'),
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

      if (confirmed == true) {
        final tenantId = ref.read(tenantSlugProvider);

        await ref.read(sessionControllerProvider(tenantId).notifier).logOut();

        if (!context.mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (_) => false,
        );
      }
    }

    final baseStyle = OutlinedButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

    // Tight header: icon-only (much less cramped)
    if (dense) {
      return Tooltip(
        message: label,
        child: OutlinedButton(
          style: baseStyle.copyWith(
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
          ),
          onPressed: doLogout,
          child: const Icon(Icons.logout, size: 18),
        ),
      );
    }

    // Normal header: icon + label
    return OutlinedButton.icon(
      icon: const Icon(Icons.logout, size: 18),
      label: Text(label),
      style: baseStyle.copyWith(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      ),
      onPressed: doLogout,
    );
  }
}
