import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/providers/users/combined_user_provider.dart';
import 'package:afyakit/users/models/combined_user.dart';

class CombinedUserGate extends ConsumerWidget {
  final bool Function(CombinedUser user) allow;
  final Widget Function(BuildContext context) builder;
  final Widget? fallback;

  const CombinedUserGate({
    super.key,
    required this.allow,
    required this.builder,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combinedUser = ref.watch(combinedUserProvider);

    return combinedUser.when(
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
