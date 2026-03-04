// lib/hq/tenants/widgets/hq_tenants_tab.dart

import 'package:afyakit/core/hq/domains/widgets/tenant_domains_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/hq/tenants/providers/hq_tenants_provider.dart'; // ✅ NEW
import 'package:afyakit/core/hq/tenants/extensions/tenant_status_x.dart';
import 'package:afyakit/core/hq/tenants/models/tenant_profile.dart';
import 'package:afyakit/core/hq/tenants/widgets/tenant_profile_editor.dart';
import 'package:afyakit/core/hq/tenants/controllers/tenant_profile_controller.dart'
    show tenantProfileEditorInputProvider;
import 'package:afyakit/core/hq/branding/widgets/tenant_branding_screen.dart';

class HqTenantsTab extends ConsumerWidget {
  const HqTenantsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfiles = ref.watch(hqTenantsProvider); // ✅ switched

    return Scaffold(
      body: asyncProfiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _ErrorState(
          message: 'Failed to load tenants: $e',
          onRetry: () => ref.invalidate(hqTenantsProvider),
        ),
        data: (profiles) {
          if (profiles.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(hqTenantsProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 140),
                  Center(
                    child: Text('No tenant profiles yet. Pull to refresh.'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(hqTenantsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: profiles.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final profile = profiles[i];
                return _TenantProfileTile(
                  profile: profile,
                  onEditProfile: () => _openEditor(context, profile),
                  onBranding: () => _openBranding(context, profile),
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
      builder: (sheetCtx) {
        // ✅ Override the editor input provider so controller loads the correct tenant.
        return ProviderScope(
          parent: ProviderScope.containerOf(sheetCtx),
          overrides: [
            tenantProfileEditorInputProvider.overrideWithValue(profile),
          ],
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: const TenantProfileEditor(),
          ),
        );
      },
    );
  }

  void _openBranding(BuildContext context, TenantProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TenantBrandingScreen(initial: profile)),
    );
  }
}

class _TenantProfileTile extends StatelessWidget {
  const _TenantProfileTile({
    required this.profile,
    required this.onEditProfile,
    required this.onBranding,
  });

  final TenantProfile profile;
  final VoidCallback onEditProfile;
  final VoidCallback onBranding;

  @override
  Widget build(BuildContext context) {
    // Very simple subtitle: status + optional website
    final subtitleParts = <String>['Status: ${profile.status.value}'];

    final website = profile.details.website;
    if (website != null && website.isNotEmpty) {
      subtitleParts.add(website);
    }

    final subtitleText = subtitleParts.join(' • ');

    // count only enabled features
    final enabledCount = profile.features.features.entries
        .where((e) => e.value == true)
        .length;

    return ListTile(
      // tile has no onTap; actions are explicit buttons
      leading: CircleAvatar(
        backgroundColor: profile.primaryColor.withOpacity(0.25),
        child: Text(
          profile.displayName.isNotEmpty
              ? profile.displayName[0].toUpperCase()
              : '?',
          style: TextStyle(color: profile.primaryColor),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(profile.displayName, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          if (enabledCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$enabledCount',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.blueGrey[700]),
              ),
            ),
        ],
      ),
      subtitle: Text(
        subtitleText,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: onBranding,
            icon: const Icon(Icons.brush, size: 16),
            label: const Text('Branding'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TenantDomainsScreen(initial: profile),
                ),
              );
            },
            icon: const Icon(Icons.public, size: 16),
            label: const Text('Domains'),
          ),

          OutlinedButton.icon(
            onPressed: onEditProfile,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Profile'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
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
