import 'package:afyakit/users/providers/combined_user_provider.dart';
import 'package:afyakit/users/controllers/user_profile_controller.dart';
import 'package:afyakit/users/models/combined_user_model.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/users/extensions/user_role_enum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DevRoleSwitcher extends ConsumerWidget {
  final CombinedUser user;
  final String tenantId;

  const DevRoleSwitcher({
    super.key,
    required this.user,
    required this.tenantId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonFormField<UserRole>(
      initialValue: user.role,
      decoration: const InputDecoration(
        labelText: 'Switch Role (dev only)',
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(),
      ),
      items: UserRole.values
          .map(
            (role) => DropdownMenuItem(
              value: role,
              child: Text(
                role.name,
              ), // name extension returns 'admin', 'manager', etc.
            ),
          )
          .toList(),
      onChanged: (selected) async {
        if (selected == null || selected == user.role) return;

        try {
          final controller = await ref.read(
            userProfileControllerProvider(tenantId).future,
          );

          await controller.updateUserRole(user.uid, selected.name);

          // ✅ Refresh combined user state
          ref.invalidate(combinedUserProvider);

          SnackService.showSuccess('✅ Role changed to ${selected.name}');
        } catch (e) {
          SnackService.showError('❌ Failed to switch role: $e');
        }
      },
    );
  }
}
