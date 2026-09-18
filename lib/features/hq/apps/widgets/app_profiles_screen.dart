// lib/features/hq/apps/widgets/app_profiles_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/models/app_profile.dart';
import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:afyakit/features/hq/apps/controllers/app_profile_controller.dart';
import 'package:afyakit/features/hq/apps/controllers/app_profile_state.dart';
import 'package:afyakit/features/hq/apps/providers/hq_app_profiles_provider.dart';
import 'package:afyakit/features/hq/apps/widgets/app_branding_screen.dart';
import 'package:afyakit/features/hq/apps/widgets/app_profile_editor.dart';

class AppProfilesScreen extends ConsumerWidget {
  const AppProfilesScreen({super.key, required this.tenant});

  final TenantProfile tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncApps = ref.watch(hqAppProfilesProvider(tenant.id));

    return Scaffold(
      appBar: AppBar(title: Text('Apps · ${tenant.id}')),
      body: asyncApps.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: 'Failed to load apps: $error',
          onRetry: () {
            ref.invalidate(hqAppProfilesProvider(tenant.id));
          },
        ),
        data: (apps) {
          if (apps.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(hqAppProfilesProvider(tenant.id));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 140),
                  Center(child: Text('No app profiles yet.')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(hqAppProfilesProvider(tenant.id));
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: apps.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final app = apps[index];

                return _AppTile(
                  profile: app,
                  onBranding: () => _openBranding(context, app),
                  onEdit: () => _openEditor(context, app),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Create app'),
      ),
    );
  }

  void _openEditor(BuildContext context, AppProfile? app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return ProviderScope(
          parent: ProviderScope.containerOf(sheetContext),
          overrides: [
            appProfileEditorInputProvider.overrideWithValue(
              AppProfileEditorInput(tenant: tenant, initial: app),
            ),
          ],
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: const AppProfileEditor(),
          ),
        );
      },
    );
  }

  void _openBranding(BuildContext context, AppProfile app) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppBrandingScreen(tenantId: tenant.id, initial: app),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.profile,
    required this.onBranding,
    required this.onEdit,
  });

  final AppProfile profile;
  final VoidCallback onBranding;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final enabledCount = profile.features.values.values
        .where((value) => value)
        .length;

    final displayName = profile.displayName.trim();

    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: profile.primaryColor.withValues(alpha: 0.15),
        child: Text(initial, style: TextStyle(color: profile.primaryColor)),
      ),
      title: Text(displayName.isNotEmpty ? displayName : profile.id),
      subtitle: Text(
        '${profile.active ? 'Active' : 'Inactive'}'
        ' • $enabledCount modules'
        ' • ${profile.id}',
      ),
      trailing: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: onBranding,
            icon: const Icon(Icons.brush, size: 16),
            label: const Text('Branding'),
          ),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Profile'),
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
