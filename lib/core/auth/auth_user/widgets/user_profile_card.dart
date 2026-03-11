// lib/core/auth/auth_user/widgets/user_profile_card.dart

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';

import 'package:afyakit/core/auth/auth_user/utils/user_format.dart';
import 'package:afyakit/shared/utils/normalize/normalize_string.dart';
import 'package:flutter/material.dart';
import 'package:afyakit/features/inventory/views/widgets/inventory_item_tile_components/editable_chip_list.dart';

class UserProfileCard extends StatelessWidget {
  /// ✅ Pass the model, not strings
  final AuthUser user;

  /// Human-facing role label (e.g. "Admin", "Manager / Pharmacist").
  /// If you don't want to compute this externally anymore, you can pass null
  /// and we will fall back to primary staff role label.
  final String? roleLabelOverride;

  /// Backend role key (e.g. "owner", "admin", "manager", "staff", "client").
  /// Used as the dropdown value when [onRoleChanged] is non-null.
  final String? roleValue;

  /// Already-resolved store labels (e.g. branch names).
  final List<String> storeLabels;

  /// Tap on avatar only
  final VoidCallback? onAvatarTapped;

  /// Tap anywhere on the card
  final VoidCallback? onTap;

  /// Called with the selected *backend* role key (owner/admin/manager/staff/client).
  final ValueChanged<String?>? onRoleChanged;

  final VoidCallback? onEditStoresTapped;
  final ValueChanged<String>? onRemoveStore;
  final VoidCallback? onDeleteUser;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(theme),
              const SizedBox(width: 16),
              Expanded(child: _buildUserInfo(theme)),
              const SizedBox(width: 8),
              _buildRightColumn(theme),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────── UI bits ─────────────────

  Widget _buildAvatar(ThemeData theme) {
    final displayName = user.computedDisplayName;
    final initials = initialsFromName(displayName);

    return GestureDetector(
      onTap: onAvatarTapped ?? onTap,
      child: CircleAvatar(
        radius: 22,
        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
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
    final safeName = user.computedDisplayName.trim().isNotEmpty
        ? user.computedDisplayName
        : 'Unnamed User';

    final safePhone = (user.phoneNumber ?? '').trim();
    final safePhoneLabel = safePhone.isNotEmpty ? safePhone : '—';

    final safeEmail = (user.bestEmailForDisplay ?? '').trim();
    final safeEmailLabel = safeEmail.isNotEmpty ? safeEmail : null;

    final statusLabel = user.status.label;

    // ✅ Truth: staff = governance/roles/superadmin (per your extension).
    final isStaff = user.isStaff;

    // ✅ Baseline: everyone is a member.
    final typeChips = <Widget>[
      _pillChip(theme, 'Member'),
      if (isStaff) _pillChip(theme, 'Staff'),
    ];

    // ✅ Staff-only role logic
    final roleLabelOverrideSafe = (roleLabelOverride ?? '').trim();

    final derivedPrimaryStaffRole =
        user.staffRoles.primaryRole?.label ?? 'Staff';

    final staffRoleLabel = roleLabelOverrideSafe.isNotEmpty
        ? roleLabelOverrideSafe
        : derivedPrimaryStaffRole;

    final extraStaffRoleChips = isStaff
        ? user.staffRoles
              .map((r) => r.label.trim())
              .where((r) => r.isNotEmpty)
              .where((r) => r.normalize() != staffRoleLabel.normalize())
              .map((r) => _pillChip(theme, r))
              .toList(growable: false)
        : const <Widget>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _buildLine(safeName, isBold: true, fontSize: 15)),
            const SizedBox(width: 8),
            _statusChip(theme, statusLabel),
          ],
        ),
        if (safeEmailLabel != null) _buildLine(safeEmailLabel),
        _buildLine(safePhoneLabel),
        const SizedBox(height: 6),

        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ...typeChips,

            // ✅ ONLY staff get a role chip (prevents Member|Member)
            if (isStaff && staffRoleLabel.trim().isNotEmpty)
              _pillChip(theme, staffRoleLabel),

            ...extraStaffRoleChips,
          ],
        ),

        if (storeLabels.isNotEmpty) ...[
          const SizedBox(height: 10),
          EditableChipList(
            labelToId: {for (final label in storeLabels) label: label},
            onRemove: onRemoveStore,
          ),
        ],
      ],
    );
  }

  Widget _buildRightColumn(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (onDeleteUser != null) _buildDeleteButton(),
        if (onRoleChanged != null) ...[
          const SizedBox(height: 4),
          _buildRoleDropdown(theme),
        ],
        if (onEditStoresTapped != null) ...[
          const SizedBox(height: 8),
          _buildEditStoresButton(),
        ],
      ],
    );
  }

  Widget _statusChip(ThemeData theme, String statusLabel) {
    final isActive = statusLabel.toLowerCase().contains('active');
    final bg = isActive
        ? theme.colorScheme.primary.withOpacity(0.08)
        : Colors.red.withOpacity(0.06);
    final border = isActive
        ? theme.colorScheme.primary.withOpacity(0.4)
        : Colors.red.withOpacity(0.4);
    final fg = isActive ? theme.colorScheme.primary : Colors.red[700];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Text(
        statusLabel.toPascalCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _pillChip(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRoleDropdown(ThemeData theme) {
    const roleOptions = <String>[
      'owner',
      'admin',
      'manager',
      'staff',
      'client',
    ];

    final current = roleValue != null && roleOptions.contains(roleValue)
        ? roleValue
        : null;

    return DropdownButton<String>(
      value: current,
      hint: const Text('Change role'),
      onChanged: onRoleChanged,
      items: roleOptions
          .map((r) => DropdownMenuItem(value: r, child: Text(r.toPascalCase())))
          .toList(),
    );
  }

  Widget _buildEditStoresButton() {
    return TextButton.icon(
      icon: const Icon(Icons.store),
      label: const Text('Edit Stores'),
      onPressed: onEditStoresTapped,
    );
  }

  Widget _buildLine(String text, {bool isBold = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return IconButton(
      icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
      tooltip: 'Delete User',
      onPressed: onDeleteUser,
    );
  }
}
