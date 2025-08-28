import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:flutter/material.dart';

class PermissionGuard extends StatelessWidget {
  final AuthUser user;
  final bool Function(AuthUser) allowed;
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
