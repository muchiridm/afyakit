import 'package:flutter/material.dart';
import 'package:afyakit/users/models/combined_user_model.dart';

class PermissionGuard extends StatelessWidget {
  final CombinedUser user;
  final bool Function(CombinedUser) allowed;
  final Widget child;
  final Widget fallback;

  const PermissionGuard({
    super.key,
    required this.user,
    required this.allowed,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    return allowed(user) ? child : fallback;
  }
}
