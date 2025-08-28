// lib/hq/core/tenants/widgets/tenant_tile.dart
import 'package:afyakit/hq/core/tenants/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/core/tenants/models/tenant_model.dart';
import 'package:afyakit/hq/core/tenants/extensions/tenant_status_x.dart';
import 'package:afyakit/hq/core/tenants/controllers/tenant_controller.dart';
import 'package:afyakit/hq/core/tenants/widgets/section_block.dart';
import 'package:afyakit/hq/core/tenants/widgets/status_chip.dart';
import 'package:afyakit/core/auth_users/models/auth_user_model.dart';

class TenantTile extends ConsumerWidget {
  const TenantTile({super.key, required this.tenant});
  final Tenant tenant; // initial snapshot

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(tenantControllerProvider);
    final live = ref.watch(tenantStreamBySlugProvider(tenant.slug));

    return live.when(
      data: (t) => _buildCard(context, controller, t),
      loading: () => _buildCard(context, controller, tenant),
      error: (_, __) => _buildCard(context, controller, tenant),
    );
  }

  Widget _buildCard(BuildContext context, TenantController c, Tenant t) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: _header(context, t),
        subtitle: _subtitle(context, t),
        trailing: _actions(context, c, t),
        children: [
          _owner(context, c, t),
          const SizedBox(height: 12),
          _admins(context, c, t),
        ],
      ),
    );
  }

  // UI bits …

  Widget _header(BuildContext context, Tenant t) {
    final initial = (t.displayName.isNotEmpty ? t.displayName[0] : t.slug[0])
        .toUpperCase();
    return Row(
      children: [
        CircleAvatar(child: Text(initial)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            t.displayName,
            style: Theme.of(context).textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        StatusChip(status: t.status),
      ],
    );
  }

  Widget _subtitle(BuildContext context, Tenant t) {
    final parts = <String>[
      t.slug,
      if (t.primaryDomain?.isNotEmpty == true) 'domain ${t.primaryDomain}',
      'color ${t.primaryColor}',
    ];
    return Padding(
      padding: const EdgeInsets.only(left: 52, top: 4),
      child: Text(
        parts.join(' • '),
        style: Theme.of(context).textTheme.bodySmall,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _actions(BuildContext context, TenantController c, Tenant t) {
    final isDeleted = t.status.isDeleted;
    final isActive = t.status.isActive;
    final statusTooltip = isDeleted
        ? 'Restore'
        : (isActive ? 'Suspend' : 'Activate');
    final statusIcon = isDeleted
        ? Icons.restore_from_trash
        : (isActive ? Icons.pause_circle : Icons.play_circle);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Configure',
          icon: const Icon(Icons.settings),
          onPressed: () => c.configureTenantWithDialog(context, tenant: t),
        ),
        IconButton(
          tooltip: 'Edit tenant',
          icon: const Icon(Icons.edit),
          onPressed: isDeleted
              ? null
              : () => c.editTenantWithDialog(
                  context,
                  slug: t.slug,
                  initialDisplayName: t.displayName,
                  initialPrimaryColor: t.primaryColor,
                  initialLogoPath: t.logoPath,
                ),
        ),
        IconButton(
          tooltip: statusTooltip,
          icon: Icon(statusIcon),
          onPressed: () => c.toggleStatusBySlug(context, t.slug, t.status),
        ),
      ],
    );
  }

  Widget _owner(BuildContext context, TenantController c, Tenant t) {
    final label = t.ownerEmail ?? t.ownerUid ?? '—';
    return SectionBlock(
      title: 'Owner',
      child: Row(
        children: [
          Expanded(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: const Text('Current Owner'),
              leading: const Icon(Icons.verified_user),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Transfer'),
            onPressed: () => c.configureTenantWithDialog(context, tenant: t),
          ),
        ],
      ),
    );
  }

  Widget _admins(BuildContext context, TenantController c, Tenant t) {
    return SectionBlock(
      title: 'Tenant Admins',
      action: TextButton.icon(
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add'),
        onPressed: t.status.isDeleted
            ? null
            : () => c.addAdminWithDialog(context, slug: t.slug),
      ),
      child: FutureBuilder<List<AuthUser>>(
        future: c.listAdminsForTenant(t.slug), // 👈 controller owns the logic
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            );
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: ${snap.error}'),
            );
          }
          final admins = snap.data ?? const <AuthUser>[];
          if (admins.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No admins yet.'),
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: admins.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final u = admins[i];
              final label = (u.email.isNotEmpty
                  ? u.email
                  : (u.phoneNumber ?? u.uid));
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.admin_panel_settings),
                title: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(u.role.wire),
                trailing: TextButton(
                  onPressed: t.status.isDeleted
                      ? null
                      : () => c.removeAdminWithConfirm(
                          context,
                          slug: t.slug,
                          uid: u.uid,
                          label: label,
                        ),
                  child: const Text('Remove'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
