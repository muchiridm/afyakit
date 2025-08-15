import 'package:afyakit/tenants/screens/create_tenant_sheet.dart';
import 'package:afyakit/tenants/screens/edit_tenant_sheet.dart';
import 'package:afyakit/tenants/tenant_controller.dart';
import 'package:afyakit/tenants/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/tenants/tenant_model.dart';

class TenantManagerScreen extends ConsumerWidget {
  const TenantManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenants = ref.watch(tenantsStreamProvider);
    final controller = ref.watch(tenantControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tenant Manager')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_business),
        label: const Text('Create Tenant'),
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => CreateTenantSheet(
            onSubmit: (payload) async {
              await controller.createTenant(
                context: context,
                displayName: payload.displayName,
                slug: payload.slug,
                primaryColor: payload.primaryColor,
                logoPath: payload.logoPath,
                flags: payload.flags,
              );
            },
          ),
        ),
      ),
      body: tenants.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load tenants: $e')),
        data: (list) {
          final sorted = [...list]
            ..sort(
              (a, b) => a.displayName.toLowerCase().compareTo(
                b.displayName.toLowerCase(),
              ),
            );

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _TenantTile(sorted[i]),
          );
        },
      ),
    );
  }
}

class _TenantTile extends ConsumerWidget {
  const _TenantTile(this.t);
  final Tenant t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(tenantControllerProvider);

    return ListTile(
      leading: CircleAvatar(
        child: Text(
          (t.displayName.isNotEmpty ? t.displayName[0] : t.slug[0])
              .toUpperCase(),
        ),
      ),
      title: Text(t.displayName),
      subtitle: Text('${t.slug} • ${t.status}'),
      trailing: Wrap(
        spacing: 8,
        children: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => EditTenantSheet(
                tenant: t,
                onSubmit: (payload) => controller.editTenant(
                  context: context,
                  slug: t.slug,
                  displayName: payload.displayName,
                  primaryColor: payload.primaryColor,
                  logoPath: payload.logoPath,
                ),
              ),
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
      ),
      onTap: () {
        // also open edit on tap if you like:
        // ...
      },
    );
  }
}
