// lib/core/hq/tenants/models/feature_registry.dart

import 'package:flutter/material.dart';

import 'package:afyakit/features/health_metrics/widgets/health_metrics_dashboard_screen.dart';

import 'feature_keys.dart';

@immutable
class FeatureDef {
  final String key;
  final String label;
  final IconData icon;
  final String? description;
  final WidgetBuilder? entry;

  const FeatureDef({
    required this.key,
    required this.label,
    required this.icon,
    this.description,
    this.entry,
  });
}

final class FeatureRegistry {
  const FeatureRegistry._();

  static const List<FeatureDef> features = <FeatureDef>[
    FeatureDef(
      key: FeatureKeys.hq,
      label: 'HQ',
      icon: Icons.admin_panel_settings,
      description: 'Admin console for managing users and preferences.',
    ),
    FeatureDef(
      key: FeatureKeys.inventory,
      label: 'Inventory',
      icon: Icons.inventory_2,
      description:
          'Stock items, batches, locations, reports, and reorder workflows.',
    ),
    FeatureDef(
      key: FeatureKeys.retail,
      label: 'Retail',
      icon: Icons.storefront,
      description:
          'Catalog, contacts, quotes, invoices, payments, and delivery.',
    ),
    FeatureDef(
      key: FeatureKeys.healthMetrics,
      label: 'Health Metrics',
      icon: Icons.monitor_heart_outlined,
      description:
          'Record and review vital signs, blood glucose, weight, BMI, and other health measurements.',
      entry: _healthMetricsEntry,
    ),
    FeatureDef(
      key: FeatureKeys.clinical,
      label: 'Clinical',
      icon: Icons.local_hospital,
      description:
          'Patient profiles, prescriptions, encounters, and clinical records.',
    ),
    FeatureDef(
      key: FeatureKeys.insurance,
      label: 'Insurance',
      icon: Icons.verified_user,
      description:
          'Insurance memberships, claim invoices, payer links, and claim tracking.',
    ),
    FeatureDef(
      key: FeatureKeys.rider,
      label: 'Rider',
      icon: Icons.delivery_dining,
      description: 'Deliveries, rider jobs, tracking, and confirmations.',
    ),
    FeatureDef(
      key: FeatureKeys.reporting,
      label: 'Reporting',
      icon: Icons.bar_chart,
      description: 'Analytics dashboards and exports.',
    ),
    FeatureDef(
      key: FeatureKeys.messaging,
      label: 'Messaging',
      icon: Icons.chat_bubble,
      description: 'Customer and staff messaging and notifications.',
    ),
    FeatureDef(
      key: FeatureKeys.backup,
      label: 'Backup',
      icon: Icons.cloud_upload,
      description: 'Backups, exports, and recovery utilities.',
    ),
  ];

  static List<String> get keys =>
      features.map((feature) => feature.key).toList(growable: false);

  static FeatureDef? byKey(String key) {
    final normalizedKey = key.trim().toLowerCase();

    for (final feature in features) {
      if (feature.key.trim().toLowerCase() == normalizedKey) {
        return feature;
      }
    }

    return null;
  }

  static Widget _healthMetricsEntry(BuildContext _) {
    return const HealthMetricsDashboardScreen();
  }
}
