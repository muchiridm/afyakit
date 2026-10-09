import 'package:flutter/material.dart';

import 'feature_keys.dart';

@immutable
class FeatureDef {
  const FeatureDef({
    required this.key,
    required this.label,
    required this.icon,
    this.description,
    this.requires = const <String>[],
    this.entry,
  });

  final String key;
  final String label;
  final IconData icon;
  final String? description;

  /// Other capabilities required by this feature.
  final List<String> requires;

  /// Optional landing page for feature navigation.
  final WidgetBuilder? entry;
}

abstract final class FeatureRegistry {
  const FeatureRegistry._();

  static const List<FeatureDef> features = [
    // ─────────────────────────────────────
    // Platform
    // ─────────────────────────────────────
    FeatureDef(
      key: FeatureKeys.core,
      label: 'Core',
      icon: Icons.apps_rounded,
      description:
          'Core application services, including identity, '
          'health profiles, records, metrics and documents.',
    ),

    FeatureDef(
      key: FeatureKeys.hq,
      label: 'HQ',
      icon: Icons.admin_panel_settings_rounded,
      description: 'Platform administration, users and preferences.',
    ),

    FeatureDef(
      key: FeatureKeys.backup,
      label: 'Backup',
      icon: Icons.cloud_upload_rounded,
      description: 'Backups, exports and recovery utilities.',
    ),

    // ─────────────────────────────────────
    // Healthcare
    // ─────────────────────────────────────
    FeatureDef(
      key: FeatureKeys.clinical,
      label: 'Clinical',
      icon: Icons.medical_information_rounded,
      description:
          'Clinical encounters, consultations, diagnoses, '
          'treatment and prescriptions.',
    ),

    FeatureDef(
      key: FeatureKeys.diagnostics,
      label: 'Diagnostics',
      icon: Icons.biotech_rounded,
      description:
          'Laboratory tests, imaging, physiological testing, '
          'diagnostic requests, results and reports.',
    ),

    FeatureDef(
      key: FeatureKeys.pharmacy,
      label: 'Pharmacy',
      icon: Icons.local_pharmacy_rounded,
      description:
          'Prescription verification, dispensing, '
          'medication orders and pharmacy services.',
    ),

    FeatureDef(
      key: FeatureKeys.occupationalHealth,
      label: 'Occupational Health',
      icon: Icons.health_and_safety_rounded,
      description:
          'Employer programmes, screening campaigns, '
          'health surveillance and fitness certification.',
    ),

    FeatureDef(
      key: FeatureKeys.insurance,
      label: 'Insurance',
      icon: Icons.verified_user_rounded,
      description:
          'Memberships, payer links, claims and '
          'insurance billing.',
    ),

    // ─────────────────────────────────────
    // Commerce and operations
    // ─────────────────────────────────────
    FeatureDef(
      key: FeatureKeys.retail,
      label: 'Retail',
      icon: Icons.storefront_rounded,
      description:
          'Catalogue, contacts, quotes, invoices, '
          'payments and sales.',
    ),

    FeatureDef(
      key: FeatureKeys.inventory,
      label: 'Inventory',
      icon: Icons.inventory_2_rounded,
      description:
          'Stock, batches, locations and '
          'reorder workflows.',
    ),

    FeatureDef(
      key: FeatureKeys.rider,
      label: 'Rider',
      icon: Icons.delivery_dining_rounded,
      description: 'Delivery jobs, tracking and confirmations.',
    ),

    // ─────────────────────────────────────
    // Shared services
    // ─────────────────────────────────────
    FeatureDef(
      key: FeatureKeys.messaging,
      label: 'Messaging',
      icon: Icons.chat_bubble_rounded,
      description: 'Messaging and notifications.',
    ),

    FeatureDef(
      key: FeatureKeys.reporting,
      label: 'Reporting',
      icon: Icons.bar_chart_rounded,
      description: 'Analytics, dashboards and exports.',
    ),
  ];

  static List<String> get keys => [for (final feature in features) feature.key];

  static FeatureDef? byKey(String key) {
    final normalized = key.trim().toLowerCase();

    for (final feature in features) {
      if (feature.key == normalized) {
        return feature;
      }
    }

    return null;
  }
}
