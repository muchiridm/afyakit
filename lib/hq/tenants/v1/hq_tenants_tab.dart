// lib/hq/core/tenants/widgets/hq_tenants_tab.dart
import 'package:afyakit/hq/tenants/v2/extensions/tenant_status_x.dart';
import 'package:afyakit/hq/tenants/v2/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// legacy v1 pieces
import 'package:afyakit/hq/tenants/v1/models/tenant_model.dart';
import 'package:afyakit/hq/tenants/v1/controllers/tenant_controller.dart';
import 'package:afyakit/hq/tenants/v1/widgets/tenant_tile.dart';

// v2 model
import 'package:afyakit/hq/tenants/v2/models/tenant_profile.dart';

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
        onPressed: () => ctrl.createTenantViaDialog(context),
      ),
      body: tenants.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load tenants: $e')),
        data: (list) {
          // list is List<TenantProfile>, but TenantTile wants Tenant
          final asV1 = list.map(_profileToTenant).toList();
          if (asV1.isEmpty) {
            return const Center(child: Text('No tenants yet.'));
          }
          return _buildList(asV1);
        },
      ),
    );
  }

  // keep signature the same
  Widget _buildList(List<Tenant> tenants) => ListView.separated(
    padding: const EdgeInsets.all(12),
    itemCount: tenants.length,
    separatorBuilder: (_, __) => const Divider(height: 1),
    itemBuilder: (_, i) => TenantTile(tenant: tenants[i]),
  );

  // ────────────────────────────────────────────────────────────
  // v2 → v1 adapter (minimal)
  // ────────────────────────────────────────────────────────────
  Tenant _profileToTenant(TenantProfile p) {
    return Tenant.fromJson({
      'slug': p.id,
      'displayName': p.displayName,
      'status': p.status.value,
      'primaryColor': p.primaryColorHex,
      // v1 fields we don’t have in v2 → null/empty
      'logoPath': null,
      'ownerEmail': null,
      'ownerUid': null,
      'primaryDomain': null,
      // dump features into flags to keep old UIs happy
      'flags': p.features.features,
    });
  }
}
