// lib/modules/core/auth_users/widgets/logout_button.dart

import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/controllers/session_controller.dart';
import 'package:afyakit/core/auth/widgets/auth_gate.dart';

class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Logout',
      icon: const Icon(Icons.logout),
      onPressed: () async {
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

          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthGate()),
              (_) => false,
            );
          }
        }
      },
    );
  }
}
