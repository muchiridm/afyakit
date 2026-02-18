// lib/hq/users/all_users/widgets/user_row_tile.dart

import 'package:afyakit/hq/users/all_users/all_user_model.dart';
import 'package:flutter/material.dart';

class UserRowTile extends StatelessWidget {
  const UserRowTile({
    super.key,
    required this.user,
    this.membershipsMap,
    this.onTap,
  });

  final AllUser user;

  /// tenantId → { role, active, email? }
  final Map<String, Map<String, Object?>>? membershipsMap;

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
              child: Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Colors.orange,
              ),
            ),
          if (user.disabled)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.block, size: 14, color: Colors.redAccent),
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
    // No tenants at all → show primary email (if any) or "No tenants"
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

    // Tenants available → one line per tenant:
    //   "tenantId   email_for_that_tenant_or_—"
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tenants.map((tid) {
          final tenantMeta = membershipsMap?[tid];

          // STRICT: use only tenant-scoped email; do NOT fall back
          // to directory/global email here. If missing, show "—".
          final perTenantEmail =
              (tenantMeta?['email'] as String?)?.trim() ?? '';
          final lineEmail = perTenantEmail.isNotEmpty ? perTenantEmail : '—';

          return Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Row(
              children: [
                Flexible(
                  flex: 2,
                  child: Text(
                    tid,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: Text(
                    lineEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Pick something sensible for the title line
  String _titleLine({required String phone, required String name}) {
    final hasPhone = phone.isNotEmpty;
    final hasName = name.isNotEmpty;

    if (hasPhone && hasName) return '$phone • $name';
    if (hasPhone) return phone;
    if (hasName) return name;
    return 'Unknown user';
  }

  // Avatar seed: prefer name, else phone, else primary email, else '?'
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
    return v[0].toUpperCase();
  }

  /// Returns tenant IDs from memberships (preferred) or from the
  /// directory doc as a fallback.
  List<String> _tenantIds() {
    if (membershipsMap != null && membershipsMap!.isNotEmpty) {
      final ids = membershipsMap!.keys.toList();
      ids.sort();
      return ids;
    }

    if (user.tenantIds.isNotEmpty) {
      final ids = List<String>.from(user.tenantIds);
      ids.sort();
      return ids;
    }

    return const <String>[];
  }

  /// Primary email used only for:
  ///  - avatar seed (if no name/phone)
  ///  - "no tenants" subtitle
  ///
  /// Prefers the first non-empty tenant email; falls back to
  /// directory/global email if nothing is set anywhere.
  String _firstTenantEmailOrDirectory() {
    // Prefer membership emails, in sorted tenant order
    if (membershipsMap != null && membershipsMap!.isNotEmpty) {
      final ids = _tenantIds();
      for (final tid in ids) {
        final email = (membershipsMap![tid]?['email'] as String?)?.trim() ?? '';
        if (email.isNotEmpty) {
          return email;
        }
      }
    }

    // Last-resort fallback: directory/global email (if present)
    final directoryEmail = ((user.email ?? user.emailLower)).trim();
    return directoryEmail;
  }
}
