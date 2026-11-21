// lib/core/auth/auth_user/widgets/user_profile_card.dart
// Read-only account-access summary. No Native Contact or auth mutations here.

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth/auth_user/utils/resolve_user_display.dart';
import 'package:afyakit/core/auth/auth_user/utils/user_format.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/shared/utils/normalize/normalize_string.dart';
import 'package:material_ui/material_ui.dart';

class UserProfileCard extends StatelessWidget {
  const UserProfileCard({
    super.key,
    required this.user,
    this.roleLabelOverride,
    this.onTap,
  });

  final AuthUser user;
  final String? roleLabelOverride;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = user.displayLabel();
    final initials = initialsFromName(name);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _accountDetails(theme, name)),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountDetails(ThemeData theme, String name) {
    final phone = (user.phoneNumber ?? '').trim();
    // App-scoped verified email only; never a Native Contact email fallback.
    final email = (user.activeAppEmailLower ?? '').trim();
    final isStaff = user.isStaff;
    final explicitRole = (roleLabelOverride ?? '').trim();
    final primaryRole = user.staffRoles.primaryRole?.label ?? 'Staff';
    final roleLabel = explicitRole.isEmpty ? primaryRole : explicitRole;
    final extraRoles = isStaff
        ? user.staffRoles
              .map((role) => role.label)
              .where((label) => label != roleLabel)
              .toSet()
              .toList()
        : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            _statusChip(theme),
          ],
        ),
        if (user.accountNumber != null) ...[
          const SizedBox(height: 3),
          Text('Account: ${user.accountNumber}', style: theme.textTheme.bodySmall),
        ],
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(phone, style: theme.textTheme.bodySmall),
        ],
        if (email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(email, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _pill(theme, 'Member'),
            if (isStaff) ...[
              _pill(theme, 'Staff'),
              if (roleLabel.isNotEmpty) _pill(theme, roleLabel),
              for (final role in extraRoles) _pill(theme, role),
            ],
          ],
        ),
      ],
    );
  }

  Widget _statusChip(ThemeData theme) {
    final active = user.isActive;
    final color = active ? theme.colorScheme.primary : theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        user.status.label.toPascalCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _pill(ThemeData theme, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
