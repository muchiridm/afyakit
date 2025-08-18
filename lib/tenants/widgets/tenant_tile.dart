// lib/hq/tenants/widgets/tenant_tile.dart
import 'package:afyakit/tenants/dialogs/add_admin_dialog.dart';
import 'package:afyakit/tenants/dialogs/confirm_dialog.dart';
import 'package:afyakit/tenants/dialogs/edit_tenant_dialog.dart';
import 'package:afyakit/tenants/dialogs/transfer_owner_dialog.dart';
import 'package:afyakit/tenants/models/tenant_dtos.dart'; // ⬅️ use DTOs
import 'package:afyakit/tenants/providers/tenant_users_providers.dart';
import 'package:afyakit/tenants/tenant_controller.dart';
import 'package:afyakit/tenants/widgets/section_block.dart';
import 'package:afyakit/tenants/widgets/status_chip.dart';
import 'package:afyakit/users/user_manager/controllers/user_manager_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TenantTile extends ConsumerWidget {
  const TenantTile({super.key, required this.tenant});
  final TenantSummary tenant; // ⬅️ was Tenant

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(tenantControllerProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: _buildHeaderRow(context, tenant),
        subtitle: _buildSubtitle(tenant),
        trailing: _buildTrailingActions(context, tenant, controller),
        children: [
          _buildOwnerSection(context, ref, tenant, controller),
          const SizedBox(height: 12),
          _buildAdminsSection(context, ref, tenant),
        ],
      ),
    );
  }

  // Header & subtitle
  Widget _buildHeaderRow(BuildContext context, TenantSummary t) {
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
          ),
        ),
        const SizedBox(width: 8),
        StatusChip(status: t.status),
      ],
    );
  }

  Widget _buildSubtitle(TenantSummary t) {
    return Padding(
      padding: const EdgeInsets.only(left: 52, top: 4),
      child: Text('${t.slug} • primary ${t.primaryColor}'),
    );
  }

  // Row actions (edit / toggle)
  Widget _buildTrailingActions(
    BuildContext context,
    TenantSummary t,
    TenantController controller,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Edit tenant',
          icon: const Icon(Icons.edit),
          onPressed: () async {
            final payload = await showDialog<EditTenantPayload>(
              context: context,
              builder: (_) => EditTenantDialog(
                initialDisplayName: t.displayName,
                initialPrimaryColor: t.primaryColor,
                initialLogoPath: t.logoPath,
              ),
            );
            if (payload != null) {
              await controller.editTenant(
                context: context,
                slug: t.slug,
                displayName: payload.displayName,
                primaryColor: payload.primaryColor,
                logoPath: payload.logoPath,
              );
            }
          },
        ),
        IconButton(
          tooltip: t.status == 'active' ? 'Suspend' : 'Activate',
          icon: Icon(
            t.status == 'active' ? Icons.pause_circle : Icons.play_circle,
          ),
          onPressed: () =>
              controller.toggleStatusBySlug(context, t.slug, t.status),
        ),
      ],
    );
  }

  // Owner section
  Widget _buildOwnerSection(
    BuildContext context,
    WidgetRef ref,
    TenantSummary t,
    TenantController controller,
  ) {
    return SectionBlock(
      title: 'Owner',
      child: Row(
        children: [
          Expanded(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                t.ownerEmail ?? t.ownerUid ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text('Current Owner'),
              leading: const Icon(Icons.verified_user),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Transfer'),
            onPressed: () async {
              final uid = await showDialog<String>(
                context: context,
                builder: (_) => const TransferOwnerDialog(),
              );
              if (uid != null && uid.trim().isNotEmpty) {
                // Backend endpoint not wired yet; keep a clear placeholder.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Transfer owner not available yet — backend pending.',
                    ),
                  ),
                );
                // When ready, call:
                // await controller.transferOwner(
                //   context,
                //   slug: t.slug,
                //   newOwnerUid: uid.trim(),
                // );
              }
            },
          ),
        ],
      ),
    );
  }

  // Admins section (uses backend stream provider)
  Widget _buildAdminsSection(
    BuildContext context,
    WidgetRef ref,
    TenantSummary t,
  ) {
    final adminsAsync = ref.watch(tenantAdminsStreamProvider(t.slug));

    return SectionBlock(
      title: 'Tenant Admins',
      action: TextButton.icon(
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add'),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AddAdminDialog(tenantSlug: t.slug),
          );
          if (ok == true) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Invite sent')));
          }
        },
      ),
      child: adminsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $e'),
        ),
        data: (admins) {
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
              final label = u.email.isNotEmpty
                  ? u.email
                  : (u.displayName.isNotEmpty ? u.displayName : u.uid);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.admin_panel_settings),
                title: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(u.role.name),
                trailing: TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => const ConfirmDialog(
                        title: 'Remove admin?',
                        message: 'This will remove admin access for this user.',
                        confirmLabel: 'Remove',
                      ),
                    );
                    if (ok == true) {
                      // Remove tenant-scoped membership via UserManagerController
                      final userCtrl = ref.read(
                        userManagerControllerProvider.notifier,
                      );
                      await userCtrl.deleteUser(u.uid);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Admin removed')),
                      );
                    }
                  },
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
