// lib/features/hq/tenants/widgets/hq_tenants_tab.dart

import 'package:afyakit/core/tenancy/models/tenant_status_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:afyakit/features/hq/apps/widgets/app_profiles_screen.dart';
import 'package:afyakit/features/hq/tenants/controllers/tenant_profile_controller.dart'
    show tenantProfileEditorInputProvider;
import 'package:afyakit/features/hq/tenants/providers/hq_tenants_provider.dart';
import 'package:afyakit/features/hq/tenants/widgets/tenant_profile_editor.dart';

class HqTenantsTab extends ConsumerWidget {
  const HqTenantsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfiles = ref.watch(hqTenantsProvider);

    return Scaffold(
      body: asyncProfiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: 'Failed to load tenants: $error',
          onRetry: () {
            ref.invalidate(hqTenantsProvider);
          },
        ),
        data: (profiles) {
          if (profiles.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(hqTenantsProvider);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 140),
                  Center(child: Text('No tenants yet. Pull to refresh.')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(hqTenantsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: profiles.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final profile = profiles[index];

                return _TenantTile(
                  profile: profile,
                  onApps: () => _openApps(context, profile),
                  onCapabilities: () => _openEditor(context, profile),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_business),
        label: const Text('Create tenant'),
        onPressed: () => _openEditor(context, null),
      ),
    );
  }

  void _openEditor(BuildContext context, TenantProfile? profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return ProviderScope(
          parent: ProviderScope.containerOf(sheetContext),
          overrides: [
            tenantProfileEditorInputProvider.overrideWithValue(profile),
          ],
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: const TenantProfileEditor(),
          ),
        );
      },
    );
  }

  void _openApps(BuildContext context, TenantProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppProfilesScreen(tenant: profile),
      ),
    );
  }
}

class _TenantTile extends StatelessWidget {
  const _TenantTile({
    required this.profile,
    required this.onApps,
    required this.onCapabilities,
  });

  final TenantProfile profile;
  final VoidCallback onApps;
  final VoidCallback onCapabilities;

  @override
  Widget build(BuildContext context) {
    final enabledCount = profile.features.values.values
        .where((enabled) => enabled)
        .length;

    final tenantId = profile.id.trim();

    final initial = tenantId.isNotEmpty ? tenantId[0].toUpperCase() : '?';

    return ListTile(
      leading: CircleAvatar(child: Text(initial)),
      title: Text(tenantId, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        'Status: ${profile.status.value}'
        ' • $enabledCount capabilities',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: onApps,
            icon: const Icon(Icons.apps, size: 16),
            label: const Text('Apps'),
          ),
          OutlinedButton.icon(
            onPressed: onCapabilities,
            icon: const Icon(Icons.tune, size: 16),
            label: const Text('Capabilities'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
