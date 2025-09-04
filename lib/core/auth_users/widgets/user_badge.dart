import 'package:afyakit/core/auth_users/providers/auth_session/current_user_providers.dart';
import 'package:afyakit/core/auth_users/utils/user_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/hq/core/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/core/auth_users/screens/user_profile_editor_screen.dart';

import 'package:afyakit/shared/utils/resolvers/resolve_user_display.dart';

class UserBadge extends ConsumerWidget {
  const UserBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final meAsync = ref.watch(
      currentAuthUserProvider,
    ); // <— canonical current user

    return meAsync.when(
      loading: () => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const Text(
        'Error',
        style: TextStyle(fontSize: 12, color: Colors.red),
      ),
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        return _buildBadge(
          context,
          displayName: user.displayLabel(), // <— unified resolver
          roleLabel: roleLabel(user.role.toString()),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileEditorScreen(tenantId: tenantId),
              ),
            );
          },
        );
      },
    );
  }

  // ────────────────── helpers ──────────────────

  Widget _buildBadge(
    BuildContext context, {
    required String displayName,
    required String roleLabel,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            Text(
              displayName,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            _roleChip(theme, roleLabel),
          ],
        ),
      ),
    );
  }

  Widget _roleChip(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Turns enums like `UserRole.admin` or raw strings like `admin` into `Admin`.
}
