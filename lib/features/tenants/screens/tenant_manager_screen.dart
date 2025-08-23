import 'package:afyakit/features/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/tenants/tenant_controller.dart';
import 'package:afyakit/features/tenants/widgets/tenant_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/tenants/models/tenant_dtos.dart';
import 'package:afyakit/features/tenants/dialogs/create_tenant_dialog.dart';

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
        onPressed: () async {
          final payload = await showDialog<CreateTenantPayload>(
            context: context,
            builder: (_) => const CreateTenantDialog(),
          );
          if (payload != null) {
            await controller.createTenant(
              context: context,
              displayName: payload.displayName,
              slug: payload.slug,
              primaryColor: payload.primaryColor,
              logoPath: payload.logoPath,
              flags: payload.flags,
            );
          }
        },
      ),
      body: tenants.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load tenants: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No tenants yet.'));
          }
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
            itemBuilder: (_, i) => TenantTile(tenant: sorted[i]),
          );
        },
      ),
    );
  }
}
