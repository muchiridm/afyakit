// lib/hq/tenants/v2/widgets/hq_tenants_v2_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/hq/tenants/v2/extensions/tenant_status_x.dart';
import 'package:afyakit/hq/tenants/v2/models/tenant_profile.dart';
import 'package:afyakit/hq/tenants/v2/providers/tenant_profile_stream_provider.dart';
import 'package:afyakit/hq/tenants/v2/widgets/tenant_profile_editor.dart';

class HqTenantsV2Tab extends ConsumerWidget {
  const HqTenantsV2Tab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfiles = ref.watch(tenantProfilesStreamProvider);

    return Scaffold(
      body: asyncProfiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Failed to load v2 tenants: $e')),
        data: (profiles) {
          if (profiles.isEmpty) {
            return const Center(child: Text('No v2 tenant profiles yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: profiles.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _TenantProfileTile(profile: profiles[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_business),
        label: const Text('Create v2 Tenant'),
        onPressed: () => _openEditor(context, null),
      ),
    );
  }

  void _openEditor(BuildContext context, TenantProfile? profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TenantProfileEditor(initial: profile),
      ),
    );
  }
}

class _TenantProfileTile extends StatelessWidget {
  const _TenantProfileTile({required this.profile});

  final TenantProfile profile;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[];

    // show tagline if present and not same as display name
    if (profile.details.tagline != null &&
        profile.details.tagline!.isNotEmpty &&
        profile.details.tagline != profile.displayName) {
      subtitleParts.add(profile.details.tagline!);
    }

    if (profile.details.website != null &&
        profile.details.website!.isNotEmpty) {
      subtitleParts.add(profile.details.website!);
    }

    subtitleParts.add('Status: ${profile.status.value}');
    final subtitle = subtitleParts.join(' • ');

    final mmName = profile.details.mobileMoneyName;
    final mmNumber = profile.details.mobileMoneyNumber;

    // count only enabled features
    final enabledCount = profile.features.features.entries
        .where((e) => e.value == true)
        .length;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: profile.primaryColor.withOpacity(0.25),
        child: Text(
          profile.displayName.isNotEmpty
              ? profile.displayName[0].toUpperCase()
              : '?',
          style: TextStyle(color: profile.primaryColor),
        ),
      ),
      title: Text(profile.displayName),
      subtitle: Text(subtitle),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // just a number
          Text('$enabledCount', style: Theme.of(context).textTheme.bodySmall),
          if (mmNumber != null && mmNumber.isNotEmpty)
            Text(
              mmName != null && mmName.isNotEmpty
                  ? '$mmName: $mmNumber'
                  : 'Mobile money: $mmNumber',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.green[700]),
            ),
        ],
      ),
      onTap: () => _openEditor(context, profile),
    );
  }

  void _openEditor(BuildContext context, TenantProfile? profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TenantProfileEditor(initial: profile),
      ),
    );
  }
}
