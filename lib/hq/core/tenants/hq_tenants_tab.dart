// lib/hq/core/tenants/widgets/hq_tenants_tab.dart
import 'package:afyakit/hq/core/tenants/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/core/tenants/models/tenant_model.dart';
import 'package:afyakit/hq/core/tenants/controllers/tenant_controller.dart';
import 'package:afyakit/hq/core/tenants/widgets/tenant_tile.dart';

class HqTenantsTab extends ConsumerWidget {
  const HqTenantsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenants = ref.watch(tenantsStreamProviderSorted);
    final ctrl = ref.watch(tenantControllerProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_business),
        label: const Text('Create Tenant'),
        onPressed: () =>
            ctrl.createTenantViaDialog(context), // 👈 controller flow
      ),
      body: tenants.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load tenants: $e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No tenants yet.'))
            : _buildList(list),
      ),
    );
  }

  Widget _buildList(List<Tenant> tenants) => ListView.separated(
    padding: const EdgeInsets.all(12),
    itemCount: tenants.length, // already sorted by provider
    separatorBuilder: (_, __) => const Divider(height: 1),
    itemBuilder: (_, i) => TenantTile(tenant: tenants[i]),
  );
}
