// lib/core/home/widgets/staff/staff_features_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/models/staff_feature_def.dart';
import 'package:afyakit/core/home/registry/home_registry.dart';
import 'package:afyakit/core/hq/tenants/models/feature_keys.dart';

import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_profiles_screen.dart';
import 'package:afyakit/features/health_metrics/widgets/health_metrics_dashboard_screen.dart';

import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_card.dart';
import 'package:afyakit/shared/widgets/app_tile.dart';

class StaffFeaturesPanel extends ConsumerWidget {
  const StaffFeaturesPanel({super.key});

  static const double _twoColBreakpoint = 720;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    if (user == null) {
      return const SizedBox.shrink();
    }

    final features = _orderedFeatures(
      HomeRegistry.featureTiles(ref, user, scope: HomeScope.staff),
    );

    if (features.isEmpty) {
      return const SizedBox.shrink();
    }

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
            builder: (context, constraints) {
              final useTwoColumns = constraints.maxWidth >= _twoColBreakpoint;

              if (!useTwoColumns) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int index = 0; index < features.length; index++) ...[
                      _FeatureTile(
                        feature: features[index],
                        user: user,
                        scope: HomeScope.staff,
                      ),
                      if (index != features.length - 1)
                        const SizedBox(height: AppShape.gap12),
                    ],
                  ],
                );
              }

              final tileWidth = (constraints.maxWidth - AppShape.gap12) / 2;

              return Wrap(
                spacing: AppShape.gap12,
                runSpacing: AppShape.gap12,
                children: [
                  for (final feature in features)
                    SizedBox(
                      width: tileWidth,
                      child: _FeatureTile(
                        feature: feature,
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

  static List<StaffFeatureDef> _orderedFeatures(
    List<StaffFeatureDef> features,
  ) {
    final ordered = [...features];

    ordered.sort((a, b) {
      final byGroup = _featureGroupRank(a).compareTo(_featureGroupRank(b));

      if (byGroup != 0) {
        return byGroup;
      }

      final byLabel = a.label.toLowerCase().compareTo(b.label.toLowerCase());

      if (byLabel != 0) {
        return byLabel;
      }

      return _featureKeyText(a).compareTo(_featureKeyText(b));
    });

    return ordered;
  }

  static int _featureGroupRank(StaffFeatureDef feature) {
    final key = _featureKeyText(feature);

    switch (key) {
      case FeatureKeys.healthMetrics:
        return 10;

      case FeatureKeys.clinical:
        return 20;

      case FeatureKeys.messaging:
        return 30;

      case FeatureKeys.retail:
        return 40;

      case FeatureKeys.insurance:
        return 50;

      case FeatureKeys.inventory:
        return 60;

      case FeatureKeys.rider:
        return 70;

      case FeatureKeys.reporting:
        return 80;

      case FeatureKeys.hq:
        return 90;

      default:
        return _fallbackGroupRank(feature);
    }
  }

  static int _fallbackGroupRank(StaffFeatureDef feature) {
    final haystack = [
      _featureKeyText(feature),
      feature.label,
      feature.description ?? '',
    ].join(' ').toLowerCase();

    if (_containsAny(haystack, const [
      'health metrics',
      'health metric',
      'vital signs',
      'vitals',
      'blood pressure',
      'blood glucose',
      'blood sugar',
      'weight',
      'bmi',
      'oxygen saturation',
      'spo2',
    ])) {
      return 10;
    }

    if (_containsAny(haystack, const [
      'clinical',
      'patient',
      'patients',
      'prescription',
      'prescriptions',
      'doctor',
      'consult',
    ])) {
      return 20;
    }

    if (_containsAny(haystack, const [
      'messaging',
      'message',
      'messages',
      'chat',
      'chats',
      'conversation',
      'conversations',
      'contact',
      'contacts',
      'customer',
      'customers',
      'whatsapp',
      'sms',
      'email',
      'inbox',
    ])) {
      return 30;
    }

    if (_containsAny(haystack, const [
      'retail',
      'catalog',
      'sales',
      'quote',
      'quotes',
      'invoice',
      'invoices',
      'payment',
      'payments',
      'delivery',
      'address',
      'addresses',
      'order',
      'orders',
      'cart',
      'checkout',
    ])) {
      return 40;
    }

    if (_containsAny(haystack, const [
      'insurance',
      'claim',
      'claims',
      'membership',
      'memberships',
      'payer',
      'payers',
      'scheme',
      'schemes',
      'policy',
      'policies',
    ])) {
      return 50;
    }

    if (_containsAny(haystack, const [
      'inventory',
      'stock',
      'store',
      'stores',
      'batch',
      'batches',
      'issue',
      'issues',
      'delivery note',
      'reorder',
      'supplier',
      'suppliers',
      'medication',
      'consumable',
      'equipment',
    ])) {
      return 60;
    }

    if (_containsAny(haystack, const [
      'rider',
      'riders',
      'dispatch',
      'courier',
    ])) {
      return 70;
    }

    if (_containsAny(haystack, const [
      'reporting',
      'report',
      'reports',
      'analytics',
      'dashboard',
      'export',
      'exports',
    ])) {
      return 80;
    }

    if (_containsAny(haystack, const [
      'admin',
      'hq',
      'user',
      'users',
      'tenant',
      'tenants',
      'setting',
      'settings',
      'role',
      'roles',
      'permission',
      'permissions',
    ])) {
      return 90;
    }

    return 100;
  }

  static bool _containsAny(String value, List<String> needles) {
    for (final needle in needles) {
      if (value.contains(needle)) {
        return true;
      }
    }

    return false;
  }

  static String _featureKeyText(StaffFeatureDef feature) {
    return feature.featureKey.trim().toLowerCase();
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
            _FeatureDescription(feature: feature),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppShape.gap10),
              Wrap(
                spacing: AppShape.gap10,
                runSpacing: AppShape.gap10,
                children: [
                  for (final action in actions) _ActionChip(action: action),
                ],
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
        if (feature.destination != null)
          const Icon(Icons.chevron_right, size: 20),
      ],
    );
  }
}

class _FeatureDescription extends StatelessWidget {
  const _FeatureDescription({required this.feature});

  final StaffFeatureDef feature;

  @override
  Widget build(BuildContext context) {
    final description = (feature.description ?? '').trim();

    if (description.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        description,
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
        onPressed: () => _handleTap(context),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    if (action.featureKey == FeatureKeys.healthMetrics) {
      await _openHealthMetrics(context);
      return;
    }

    final destination = action.destination;

    if (destination == null) {
      SnackService.showError('🚧 ${action.label} is not wired yet.');
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: destination));
  }

  Future<void> _openHealthMetrics(BuildContext context) async {
    final patient = await Navigator.of(context).push<PatientProfile>(
      MaterialPageRoute<PatientProfile>(
        builder: (_) => const PatientProfilesScreen(
          allowExplicitContactLink: true,
          selectionMode: true,
          selectionTitle: 'Select patient for health metrics',
        ),
      ),
    );

    if (patient == null || !context.mounted) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HealthMetricsDashboardScreen(initialPatient: patient),
      ),
    );
  }
}
