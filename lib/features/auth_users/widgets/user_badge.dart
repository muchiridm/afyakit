import 'package:afyakit/features/auth_users/models/auth_user_model.dart';
import 'package:afyakit/features/auth_users/screens/user_profile_editor_screen.dart';
import 'package:afyakit/features/auth_users/user_manager/controllers/user_manager_controller.dart';
import 'package:afyakit/features/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/features/auth_users/user_operations/providers/current_user_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Canonical "me" in this tenant: resolves Firebase user → AuthUser doc
final myAuthUserProvider = FutureProvider.autoDispose<AuthUser?>((ref) async {
  // Rebuild if tenant changes
  final _ = ref.watch(tenantIdProvider);

  // Wait for Firebase session so we know which UID to load
  final fbUser = await ref.watch(currentUserFutureProvider.future);
  if (fbUser == null) return null;

  // Use your controller’s byId() path (single source of truth)
  final ctrl = ref.read(userManagerControllerProvider.notifier);
  return await ctrl.getUserById(fbUser.uid);
});

class UserBadge extends ConsumerWidget {
  const UserBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final meAsync = ref.watch(myAuthUserProvider);

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
          user,
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
    BuildContext context,
    AuthUser user, {
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final displayName = _displayName(user);
    final roleLabel = _roleLabel(user);

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

  String _displayName(AuthUser u) {
    final name = (u.displayName).trim();
    if (name.isNotEmpty) return name;
    if (u.email.trim().isNotEmpty) return u.email.trim();
    final phone = (u.phoneNumber ?? '').trim();
    if (phone.isNotEmpty) return phone;
    return u.uid;
  }

  /// Turns enums like `UserRole.admin` or raw strings like `admin` into `Admin`.
  String _roleLabel(AuthUser u) {
    final raw = u.role.toString().trim();
    if (raw.isEmpty) return '—';
    final cleaned = raw.contains('.') ? raw.split('.').last : raw;
    return _capitalize(cleaned);
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
