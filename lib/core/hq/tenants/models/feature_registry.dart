// lib/core/hq/tenants/models/feature_registry.dart

import 'package:flutter/material.dart';

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
      key: FeatureKeys.clinical,
      label: 'Clinical',
      icon: Icons.local_hospital,
      description:
          'Patient profiles, prescriptions, encounters, and clinical records.',
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
      features.map((f) => f.key).toList(growable: false);

  static FeatureDef? byKey(String key) {
    for (final f in features) {
      if (f.key == key) return f;
    }
    return null;
  }
}
