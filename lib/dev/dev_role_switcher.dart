import 'package:afyakit/users/providers/combined_user_provider.dart';
import 'package:afyakit/users/models/combined_user_model.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/users/extensions/user_role_enum.dart';
import 'package:afyakit/users/providers/user_engine_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ✅ NEW: engine + Result
import 'package:afyakit/shared/types/result.dart';

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
          .map((role) => DropdownMenuItem(value: role, child: Text(role.name)))
          .toList(),
      onChanged: (selected) async {
        if (selected == null || selected == user.role) return;

        try {
          // ✅ Use engine instead of controller
          final engine = await ref.read(profileEngineProvider(tenantId).future);
          final res = await engine.updateRole(user.uid, selected.name);

          if (res is Err<void>) {
            SnackService.showError(
              '❌ Failed to switch role: ${res.error.message}',
            );
            return;
          }

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
