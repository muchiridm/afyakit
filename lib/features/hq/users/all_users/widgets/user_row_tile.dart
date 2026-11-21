import 'package:afyakit/features/hq/users/all_users/all_user_model.dart';
import 'package:flutter/material.dart';

/// A global user row with tenant- and application-scoped email summaries.
/// Never derives an app email from a tenant or Firebase Auth email.
class UserRowTile extends StatelessWidget {
  const UserRowTile({
    super.key,
    required this.user,
    required this.memberships,
    this.selectedTenantId,
    this.selectedAppIds = const <String>{},
    this.onTap,
  });

  final AllUser user;
  final List<AllUserMembership> memberships;

  /// Optional context from the HQ Users filters.
  final String? selectedTenantId;
  final Set<String> selectedAppIds;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phone = (user.phoneNumber ?? '').trim();
    final name = (user.displayName ?? '').trim();
    final tenants = _visibleMemberships();

    return ListTile(
      dense: true,
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: user.disabled
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primaryContainer,
        child: Text(
          _initial(name.isNotEmpty ? name : phone),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: user.disabled
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _title(phone: phone, name: name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (!user.authExists)
            const Tooltip(
              message: 'Firebase Auth user missing',
              child: Icon(Icons.warning_amber_rounded, size: 17),
            ),
          if (user.disabled)
            const Tooltip(
              message: 'Directory user disabled',
              child: Icon(Icons.block, size: 16),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: tenants.isEmpty
            ? Text('No tenant memberships', style: theme.textTheme.bodySmall)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final membership in tenants)
                    _membershipSummary(context, membership),
                ],
              ),
      ),
    );
  }

  Widget _membershipSummary(
    BuildContext context,
    AllUserMembership membership,
  ) {
    final theme = Theme.of(context);
    final appIds = _visibleAppIds(membership);
    final status = membership.active ? '' : ' · tenant disabled';

    if (appIds.isEmpty) {
      return Text(
        '${membership.tenantId} · No application memberships$status',
        style: theme.textTheme.bodySmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final appId in appIds)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Icon(
                  membership.isEmailVerifiedForApp(appId)
                      ? Icons.verified_outlined
                      : Icons.alternate_email,
                  size: 14,
                  color: membership.isEmailVerifiedForApp(appId)
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _appLine(membership, appId, status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _appLine(
    AllUserMembership membership,
    String appId,
    String tenantStatus,
  ) {
    final email = membership.emailForApp(appId)?.trim() ?? '';
    final emailText = email.isEmpty
        ? 'Email not available'
        : membership.isEmailVerifiedForApp(appId)
        ? email
        : '$email (unverified)';
    final appStatus = membership.hasActiveAppMembership(appId)
        ? ''
        : ' · access disabled';
    final roles = membership.effectiveRolesForApp(appId);
    final roleText = roles.isNotEmpty ? ' · ${roles.join(', ')}' : '';
    return '${membership.tenantId} / $appId · $emailText$roleText$appStatus$tenantStatus';
  }

  List<AllUserMembership> _visibleMemberships() {
    final tenant = (selectedTenantId ?? '').trim().toLowerCase();
    final result = memberships.where((m) {
      return tenant.isEmpty || m.tenantId.trim().toLowerCase() == tenant;
    }).toList()..sort((a, b) => a.tenantId.compareTo(b.tenantId));
    return result;
  }

  List<String> _visibleAppIds(AllUserMembership membership) {
    final ids = <String>{
      ...membership.appMembershipsByApp.keys,
      ...membership.emailsByApp.keys,
    };
    if (selectedAppIds.isNotEmpty) {
      final filter = selectedAppIds
          .map((id) => id.trim().toLowerCase())
          .toSet();
      ids.removeWhere((id) => !filter.contains(id));
    }
    return ids.toList()..sort();
  }

  String _title({required String phone, required String name}) {
    if (phone.isNotEmpty && name.isNotEmpty) return '$phone • $name';
    if (phone.isNotEmpty) return phone;
    if (name.isNotEmpty) return name;
    return 'Unknown user';
  }

  String _initial(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }
}
