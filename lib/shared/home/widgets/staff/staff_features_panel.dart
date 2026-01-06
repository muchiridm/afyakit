import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/core/auth_user/providers/current_user_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_profile_providers.dart';
import 'package:afyakit/shared/home/models/staff_feature_def.dart';
import 'package:afyakit/shared/home/registry/staff_home_registry.dart';
import 'package:afyakit/shared/home/widgets/common/home_card.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StaffFeaturesPanel extends ConsumerWidget {
  const StaffFeaturesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    if (user == null) return const SizedBox.shrink();

    final profileAsync = ref.watch(tenantProfileProvider);
    if (profileAsync.isLoading) return const SizedBox.shrink();
    if (profileAsync.hasError) return const SizedBox.shrink();

    final features = StaffHomeRegistry.featureTiles(ref, user);

    if (features.isEmpty) return const SizedBox.shrink();

    return HomeCard(
      title: 'Features',
      icon: Icons.grid_view_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Features you are subscribed to:',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: features
                .map((f) => _FeatureTile(feature: f, user: user))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends ConsumerWidget {
  const _FeatureTile({required this.feature, required this.user});

  final StaffFeatureDef feature;
  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = StaffHomeRegistry.actionsFor(ref, user, feature.featureKey);

    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 380),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor.withOpacity(0.20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FeatureHeader(feature: feature),
              _FeatureDesc(feature: feature),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 10),
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
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(feature.icon, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            feature.label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Icon(Icons.chevron_right, size: 20),
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
      child: Text(
        d,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
      ),
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
