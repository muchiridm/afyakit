// lib/hq/users/all_users/widgets/user_row_tile.dart

import 'package:afyakit/core/hq/users/all_users/all_user_model.dart';
import 'package:flutter/material.dart';

class UserRowTile extends StatelessWidget {
  const UserRowTile({
    super.key,
    required this.user,
    required this.memberships,
    this.onTap,
  });

  final AllUser user;

  /// Embedded memberships from `/api/users`.
  ///
  /// These should be joined by the backend from tenant auth_users SOT.
  final List<AllUserMembership> memberships;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final phone = (user.phoneNumber ?? '').trim();
    final name = (user.displayName ?? '').trim();
    final primaryEmail = _firstTenantEmailOrDirectory();

    final tenants = _tenantIds();
    final hasTenants = tenants.isNotEmpty;

    return ListTile(
      dense: true,
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: user.disabled
            ? Colors.grey.shade300
            : Colors.blue.shade50,
        child: Text(
          _initial(
            _avatarSource(phone: phone, name: name, email: primaryEmail),
          ),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: user.disabled ? Colors.grey.shade700 : Colors.blue,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _titleLine(phone: phone, name: name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (!user.authExists)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Tooltip(
                message: 'Firebase Auth user missing',
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Colors.orange,
                ),
              ),
            ),
          if (user.disabled)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Tooltip(
                message: 'Directory user disabled',
                child: Icon(Icons.block, size: 14, color: Colors.redAccent),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      subtitle: _buildSubtitle(
        tenants: tenants,
        primaryEmail: primaryEmail,
        hasTenants: hasTenants,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Build helpers
  // ─────────────────────────────────────────────

  Widget _buildSubtitle({
    required List<String> tenants,
    required String primaryEmail,
    required bool hasTenants,
  }) {
    if (!hasTenants) {
      if (primaryEmail.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            primaryEmail,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          'No tenants',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tenants.map((tenantId) {
          final membership = _membershipForTenant(tenantId);

          // STRICT:
          // Use only tenant-scoped email.
          // Do NOT fall back to directory/global email here.
          final perTenantEmail = membership?.email?.trim() ?? '';
          final lineEmail = perTenantEmail.isNotEmpty ? perTenantEmail : '—';

          final role = membership?.role.trim() ?? '';
          final active = membership?.active ?? true;

          final rightText = role.isEmpty
              ? lineEmail
              : '$lineEmail · $role${active ? '' : ' · disabled'}';

          return Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Row(
              children: [
                Flexible(
                  flex: 2,
                  child: Text(
                    tenantId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: active
                          ? Colors.grey.shade800
                          : Colors.orange.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: Text(
                    rightText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: active
                          ? Colors.grey.shade600
                          : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _titleLine({required String phone, required String name}) {
    final hasPhone = phone.isNotEmpty;
    final hasName = name.isNotEmpty;

    if (hasPhone && hasName) return '$phone • $name';
    if (hasPhone) return phone;
    if (hasName) return name;

    final email = (user.email ?? user.emailLower).trim();
    if (email.isNotEmpty) return email;

    return 'Unknown user';
  }

  String _avatarSource({
    required String phone,
    required String name,
    required String email,
  }) {
    if (name.isNotEmpty) return name;
    if (phone.isNotEmpty) return phone;
    if (email.isNotEmpty) return email;
    return '?';
  }

  String _initial(String s) {
    final v = s.trim();
    if (v.isEmpty) return '?';
    return v.characters.first.toUpperCase();
  }

  List<String> _tenantIds() {
    if (memberships.isNotEmpty) {
      final ids =
          memberships
              .map((m) => m.tenantId.trim())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      return ids;
    }

    if (user.tenantIds.isNotEmpty) {
      final ids =
          user.tenantIds
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      return ids;
    }

    return const <String>[];
  }

  AllUserMembership? _membershipForTenant(String tenantId) {
    final target = tenantId.trim();

    if (target.isEmpty) return null;

    for (final membership in memberships) {
      if (membership.tenantId.trim() == target) {
        return membership;
      }
    }

    return null;
  }

  String _firstTenantEmailOrDirectory() {
    if (memberships.isNotEmpty) {
      final sorted = List<AllUserMembership>.from(memberships)
        ..sort((a, b) => a.tenantId.compareTo(b.tenantId));

      for (final membership in sorted) {
        final email = membership.email?.trim() ?? '';
        if (email.isNotEmpty) return email;
      }
    }

    return (user.email ?? user.emailLower).trim();
  }
}
