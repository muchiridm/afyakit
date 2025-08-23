import 'package:afyakit/features/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/tenants/providers/tenant_user_providers.dart';
import 'package:afyakit/features/tenants/tenant_controller.dart';
import 'package:afyakit/features/tenants/widgets/section_block.dart';
import 'package:afyakit/features/tenants/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/tenants/models/tenant_dtos.dart';

/// Fully-dumb tile:
/// - No dialogs
/// - No business logic
/// - No direct calls to UserManager engine
/// It only renders data and forwards taps to controller methods.
class TenantTile extends ConsumerWidget {
  const TenantTile({super.key, required this.tenant});
  final TenantSummary tenant; // initial snapshot (for graceful loading)

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(tenantControllerProvider);
    final live = ref.watch(tenantStreamBySlugProvider(tenant.slug));

    return live.when(
      data: (t) => _buildCard(context, ref, t, controller),
      loading: () => _buildCard(context, ref, tenant, controller),
      error: (_, __) => _buildCard(context, ref, tenant, controller),
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    TenantSummary t,
    TenantController controller,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: _buildHeaderRow(context, t),
        subtitle: _buildSubtitle(t),
        trailing: _buildTrailingActions(context, t, controller),
        children: [
          _buildOwnerSection(context, t),
          const SizedBox(height: 12),
          _buildAdminsSection(context, ref, t, controller), // Firestore stream
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

  Widget _buildSubtitle(TenantSummary t) => Padding(
    padding: const EdgeInsets.only(left: 52, top: 4),
    child: Text('${t.slug} • primary ${t.primaryColor}'),
  );

  // Row actions (edit / toggle) — forward to controller
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
          onPressed: () => controller.editTenantWithDialog(
            context,
            slug: t.slug,
            initialDisplayName: t.displayName,
            initialPrimaryColor: t.primaryColor,
            initialLogoPath: t.logoPath,
          ),
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

  // Owner section (read-only for now)
  Widget _buildOwnerSection(BuildContext context, TenantSummary t) {
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
            onPressed: () {
              // future: controller.transferOwnerWithDialog(...)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Transfer owner not available yet — backend pending.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Admins section (stream render only). Actions → controller.
  Widget _buildAdminsSection(
    BuildContext context,
    WidgetRef ref,
    TenantSummary t,
    TenantController controller,
  ) {
    final adminsAsync = ref.watch(tenantAdminsStreamProvider(t.slug));

    return SectionBlock(
      title: 'Tenant Admins',
      action: TextButton.icon(
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add'),
        onPressed: () => controller.addAdminWithDialog(context, slug: t.slug),
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
              final tm = admins[i];
              final u = tm.user;
              final label = (u.email ?? u.emailLower);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.admin_panel_settings),
                title: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(tm.role),
                trailing: TextButton(
                  onPressed: () => controller.removeAdminWithConfirm(
                    context,
                    slug: t.slug,
                    uid: u.id,
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
