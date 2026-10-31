// lib/core/auth/auth_user/widgets/user_profile_card.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth/auth_user/utils/user_format.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

import 'package:afyakit/shared/utils/normalize/normalize_string.dart';

class UserProfileCard extends StatelessWidget {
  const UserProfileCard({
    super.key,
    required this.user,
    this.roleLabelOverride,
    this.roleValue,
    required this.storeLabels,
    this.onAvatarTapped,
    this.onTap,
    this.onRoleChanged,
    this.onEditStoresTapped,
    this.onRemoveStore,
    this.onDeleteUser,
  });

  final AuthUser user;
  final String? roleLabelOverride;
  final String? roleValue;
  final List<String> storeLabels;

  final VoidCallback? onAvatarTapped;
  final VoidCallback? onTap;
  final ValueChanged<String?>? onRoleChanged;
  final VoidCallback? onEditStoresTapped;
  final ValueChanged<String>? onRemoveStore;
  final VoidCallback? onDeleteUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 460;

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAvatar(theme),
                        const SizedBox(width: 12),
                        Expanded(child: _buildUserInfo(theme)),
                      ],
                    ),
                    if (_hasActions) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildActions(),
                      ),
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(theme),
                  const SizedBox(width: 16),
                  Expanded(child: _buildUserInfo(theme)),
                  if (_hasActions) ...[
                    const SizedBox(width: 8),
                    _buildActions(),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  bool get _hasActions =>
      onDeleteUser != null ||
      onRoleChanged != null ||
      onEditStoresTapped != null;

  Widget _buildAvatar(ThemeData theme) {
    final initials = initialsFromName(user.computedDisplayName);

    return GestureDetector(
      onTap: onAvatarTapped ?? onTap,
      child: CircleAvatar(
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
    );
  }

  Widget _buildUserInfo(ThemeData theme) {
    final displayName = user.computedDisplayName.trim();

    final name = displayName.isEmpty ? 'Unnamed User' : displayName;

    final phone = (user.phoneNumber ?? '').trim();
    final email = (user.bestEmailForDisplay ?? '').trim();

    final isStaff = user.isStaff;

    final override = (roleLabelOverride ?? '').trim();

    final primaryRole = user.staffRoles.primaryRole?.label ?? 'Staff';

    final roleLabel = override.isNotEmpty ? override : primaryRole;

    final extraRoles = isStaff
        ? user.staffRoles
              .map((role) => role.label.trim())
              .where((label) => label.isNotEmpty)
              .where((label) => label.normalize() != roleLabel.normalize())
              .toSet()
              .toList(growable: false)
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
        if (email.isNotEmpty) ...[const SizedBox(height: 4), Text(email)],
        const SizedBox(height: 2),
        Text(phone.isEmpty ? '—' : phone),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _pillChip(theme, 'Member'),
            if (isStaff) ...[
              _pillChip(theme, 'Staff'),
              if (roleLabel.isNotEmpty) _pillChip(theme, roleLabel),
              for (final role in extraRoles) _pillChip(theme, role),
            ],
          ],
        ),
        if (storeLabels.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Assigned stores', style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final label in storeLabels)
                InputChip(
                  label: Text(label),
                  visualDensity: VisualDensity.compact,
                  onDeleted: onRemoveStore == null
                      ? null
                      : () => onRemoveStore!(label),
                ),
            ],
          ),
        ],
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

  Widget _pillChip(ThemeData theme, String label) {
    return Container(
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

  Widget _buildActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (onRoleChanged != null) _buildRoleDropdown(),
        if (onEditStoresTapped != null)
          TextButton.icon(
            icon: const Icon(Icons.store_outlined),
            label: const Text('Edit Stores'),
            onPressed: onEditStoresTapped,
          ),
        if (onDeleteUser != null)
          IconButton(
            icon: const Icon(
              Icons.delete_forever_outlined,
              color: Colors.redAccent,
            ),
            tooltip: 'Delete User',
            onPressed: onDeleteUser,
          ),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    const roles = <String>['owner', 'admin', 'manager', 'staff', 'client'];

    final selected = roleValue != null && roles.contains(roleValue)
        ? roleValue
        : null;

    return DropdownButton<String>(
      value: selected,
      hint: const Text('Change role'),
      onChanged: onRoleChanged,
      items: [
        for (final role in roles)
          DropdownMenuItem(value: role, child: Text(role.toPascalCase())),
      ],
    );
  }
}
