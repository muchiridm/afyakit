import 'package:afyakit/shared/home/registry/staff_home_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/core/auth_user/providers/current_user_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_profile_providers.dart';
import 'package:afyakit/shared/home/models/staff_feature_def.dart';
import 'package:afyakit/shared/services/snack_service.dart';

class StaffFeatureCards extends ConsumerWidget {
  const StaffFeatureCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    // If no user yet, don't render.
    if (user == null) return const SizedBox.shrink();

    // Tenancy profile is required for tenant-gated modules.
    final profileAsync = ref.watch(tenantProfileProvider);
    if (profileAsync.isLoading) return const SizedBox.shrink();
    if (profileAsync.hasError) return const SizedBox.shrink();

    final features = StaffHomeRegistry.featureTiles(ref, user);

    if (features.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: features
          .map((f) => _FeatureCard(feature: f, user: user))
          .toList(),
    );
  }
}

class _FeatureCard extends ConsumerWidget {
  const _FeatureCard({required this.feature, required this.user});

  final StaffFeatureDef feature;
  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = StaffHomeRegistry.actionsFor(ref, user, feature.featureKey);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 380),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FeatureHeader(feature: feature),
              _FeatureDesc(feature: feature),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: actions.map((a) => _ActionChip(action: a)).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureHeader extends StatelessWidget {
  const _FeatureHeader({required this.feature});
  final StaffFeatureDef feature;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(feature.icon),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            feature.label,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const Icon(Icons.chevron_right),
      ],
    );
  }
}

class _FeatureDesc extends StatelessWidget {
  const _FeatureDesc({required this.feature});
  final StaffFeatureDef feature;

  @override
  Widget build(BuildContext context) {
    final d = (feature.description ?? '').trim();
    if (d.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(d, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.action});
  final StaffFeatureDef action;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        icon: Icon(action.icon, size: 18),
        label: Text(action.label),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        onPressed: () {
          final dest = action.destination;
          if (dest == null) {
            SnackService.showError('🚧 ${action.label} is not wired yet.');
            return;
          }
          Navigator.of(context).push(MaterialPageRoute(builder: dest));
        },
      ),
    );
  }
}
