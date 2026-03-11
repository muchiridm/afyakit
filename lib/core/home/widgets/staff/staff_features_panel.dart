// lib/core/home/widgets/staff/staff_features_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/home/models/staff_feature_def.dart';
import 'package:afyakit/core/home/registry/home_registry.dart'; // ✅ use unified registry
import 'package:afyakit/shared/services/snack_service.dart';

import 'package:afyakit/shared/widgets/app_card.dart';
import 'package:afyakit/shared/widgets/app_tile.dart';
import 'package:afyakit/shared/theme/app_shape.dart';

class StaffFeaturesPanel extends ConsumerWidget {
  const StaffFeaturesPanel({super.key});

  static const double _twoColBreakpoint = 720;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final features = HomeRegistry.featureTiles(
      ref,
      user,
      scope: HomeScope.staff,
    );
    if (features.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return AppCard(
      title: 'Features',
      icon: Icons.grid_view_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Features you are subscribed to:',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: AppShape.gap12),
          LayoutBuilder(
            builder: (context, c) {
              final twoCol = c.maxWidth >= _twoColBreakpoint;

              if (!twoCol) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < features.length; i++) ...[
                      _FeatureTile(
                        feature: features[i],
                        user: user,
                        scope: HomeScope.staff,
                      ),
                      if (i != features.length - 1)
                        const SizedBox(height: AppShape.gap12),
                    ],
                  ],
                );
              }

              final tileW = (c.maxWidth - AppShape.gap12) / 2;

              return Wrap(
                spacing: AppShape.gap12,
                runSpacing: AppShape.gap12,
                children: [
                  for (final f in features)
                    SizedBox(
                      width: tileW,
                      child: _FeatureTile(
                        feature: f,
                        user: user,
                        scope: HomeScope.staff,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends ConsumerWidget {
  const _FeatureTile({
    required this.feature,
    required this.user,
    required this.scope,
  });

  final StaffFeatureDef feature;
  final AuthUser user;
  final HomeScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = HomeRegistry.actionsFor(
      ref,
      user,
      feature.featureKey,
      scope: scope,
    );

    return SizedBox(
      width: double.infinity,
      child: AppTile(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FeatureHeader(feature: feature),
            _FeatureDesc(feature: feature),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppShape.gap10),
              Wrap(
                spacing: AppShape.gap10,
                runSpacing: AppShape.gap10,
                children: actions.map((a) => _ActionChip(action: a)).toList(),
              ),
            ],
          ],
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
        const SizedBox(width: AppShape.gap10),
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
    final theme = Theme.of(context);
    final d = (feature.description ?? '').trim();
    if (d.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        d,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
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
