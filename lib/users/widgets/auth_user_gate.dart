// lib/users/widgets/auth_user_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/users/controllers/session_controller.dart';
import 'package:afyakit/users/models/auth_user_model.dart';

class AuthUserGate extends ConsumerWidget {
  final bool Function(AuthUser user) allow;
  final Widget Function(BuildContext context) builder;
  final Widget? fallback;

  const AuthUserGate({
    super.key,
    required this.allow,
    required this.builder,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final authUserAsync = ref.watch(sessionControllerProvider(tenantId));

    return authUserAsync.when(
      data: (user) {
        if (user != null && allow(user)) {
          return builder(context);
        }
        return fallback ?? const Center(child: Text('🚫 Access Denied'));
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading user: $e')),
    );
  }
}
