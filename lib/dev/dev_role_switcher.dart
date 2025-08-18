import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/types/result.dart';
import 'package:afyakit/users/extensions/user_role_enum.dart';
import 'package:afyakit/users/extensions/user_role_x.dart';
import 'package:afyakit/users/providers/user_engine_providers.dart'; // authUserEngineProvider
import 'package:afyakit/users/providers/auth_users_provider.dart'; // list invalidation
import 'package:afyakit/users/controllers/session_controller.dart'; // reload if self
import 'package:afyakit/users/models/auth_user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DevRoleSwitcher extends ConsumerWidget {
  final AuthUser user;
  final String tenantId;

  const DevRoleSwitcher({
    super.key,
    required this.user,
    required this.tenantId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRole = _currentRoleFromAuth(user);
    return DropdownButtonFormField<UserRole>(
      initialValue: currentRole,
      decoration: const InputDecoration(
        labelText: 'Switch Role (dev only)',
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(),
      ),
      items: UserRole.values
          .map((role) => DropdownMenuItem(value: role, child: Text(role.label)))
          .toList(),
      onChanged: (selected) async {
        if (selected == null || selected == currentRole) return;

        try {
          final engine = await ref.read(
            authUserEngineProvider(tenantId).future,
          );
          final res = await engine.setRole(user.uid, selected.name);
          if (res is Err<void>) {
            SnackService.showError(
              '❌ Failed to switch role: ${res.error.message}',
            );
            return;
          }

          // refresh lists
          ref.invalidate(authUsersProvider);

          // if changing my own role, reload session to pick up claims/role
          final selfUid = ref
              .read(sessionControllerProvider(tenantId))
              .value
              ?.uid;
          if (selfUid == user.uid) {
            await ref
                .read(sessionControllerProvider(tenantId).notifier)
                .reload(forceRefresh: true);
          }

          SnackService.showSuccess('✅ Role changed to ${selected.name}');
        } catch (e) {
          SnackService.showError('❌ Failed to switch role: $e');
        }
      },
    );
  }

  UserRole _currentRoleFromAuth(AuthUser u) {
    // prefer explicit field if your AuthUser now carries `role`
    final fromField = (u as dynamic)?.role; // ignore if not present
    if (fromField is String && fromField.isNotEmpty) {
      return parseUserRole(fromField);
    }
    // else fall back to custom claims
    final claimRole = (u.claims?['role'] as String?)?.trim();
    return parseUserRole(claimRole ?? 'staff');
  }
}
