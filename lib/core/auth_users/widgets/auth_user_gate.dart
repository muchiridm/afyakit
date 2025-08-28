// lib/users/widgets/auth_user_gate.dart
import 'package:afyakit/core/auth_users/providers/current_auth_user_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth_users/models/auth_user_model.dart';

class AuthUserGate extends ConsumerWidget {
  final bool Function(AuthUser user) allow;
  final WidgetBuilder builder;
  final Widget? fallback;
  final Widget? loading;

  const AuthUserGate({
    super.key,
    required this.allow,
    required this.builder,
    this.fallback,
    this.loading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ This one merges Firestore user + *fresh* ID-token claims
    final auth = ref.watch(currentAuthUserProvider);

    return auth.when(
      loading: () =>
          loading ?? const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          fallback ?? Center(child: Text('Error loading user: $e')),
      data: (user) {
        if (user != null && allow(user)) return builder(context);
        return fallback ?? const Center(child: Text('🚫 Access Denied'));
      },
    );
  }
}
