import 'package:flutter/material.dart';

import 'feature_keys.dart';

/// A single "feature" that can be toggled per tenant.
///
/// Keep it simple:
/// - key = stored in tenant.features map
/// - label/icon/description = used for HQ editor + staff feature tiles
/// - entry is optional: wire a feature home screen when ready
@immutable
class FeatureDef {
  final String key;
  final String label;
  final IconData icon;
  final String? description;

  /// Optional: staff feature home screen builder.
  /// If null, feature can still be enabled, but navigation should be guarded by the UI.
  final WidgetBuilder? entry;

  const FeatureDef({
    required this.key,
    required this.label,
    required this.icon,
    this.description,
    this.entry,
  });
}

/// Extremely simple registry:
/// - One list
/// - Order here is the order you’ll show in HQ + staff home
final class FeatureRegistry {
  const FeatureRegistry._();

  /// All features that can appear in HQ tenant editor / staff feature tiles.
  static const List<FeatureDef> features = <FeatureDef>[
    // Platform / admin
    FeatureDef(
      key: FeatureKeys.hq,
      label: 'HQ',
      icon: Icons.admin_panel_settings_outlined,
      description: 'Admin console for managing users and preferences.',
    ),

    // Core business features
    FeatureDef(
      key: FeatureKeys.inventory,
      label: 'Inventory',
      icon: Icons.inventory_2_outlined,
      description: 'Stock items, batches, locations, reports, reorder.',
    ),
    FeatureDef(
      key: FeatureKeys.retail,
      label: 'Retail',
      icon: Icons.storefront_outlined,
      description: 'Catalog, carts, orders, payments, delivery.',
    ),

    // Clinical
    FeatureDef(
      key: FeatureKeys.dispensing,
      label: 'Dispensing',
      icon: Icons.medical_services_outlined,
      description: 'Upload and verify prescriptions; dispense workflow.',
    ),
    FeatureDef(
      key: FeatureKeys.labs,
      label: 'Labs',
      icon: Icons.science_outlined,
      description: 'Lab requests, results, and reporting.',
    ),
    FeatureDef(
      key: FeatureKeys.consultation,
      label: 'Consultation',
      icon: Icons.video_call_outlined,
      description: 'Provider consultations and notes.',
    ),

    // Logistics
    FeatureDef(
      key: FeatureKeys.rider,
      label: 'Rider',
      icon: Icons.delivery_dining_outlined,
      description: 'Deliveries, rider jobs, tracking, confirmations.',
    ),

    // Optional / future
    FeatureDef(
      key: FeatureKeys.reporting,
      label: 'Reporting',
      icon: Icons.bar_chart_outlined,
      description: 'Analytics dashboards and exports.',
    ),
    FeatureDef(
      key: FeatureKeys.messaging,
      label: 'Messaging',
      icon: Icons.chat_bubble_outline,
      description: 'Customer and staff messaging / notifications.',
    ),
    FeatureDef(
      key: FeatureKeys.backup,
      label: 'Backup',
      icon: Icons.cloud_upload_outlined,
      description: 'Backups, exports, and recovery utilities.',
    ),
  ];

  /// Convenience: keys only (useful for editors/validation).
  static List<String> get keys =>
      features.map((f) => f.key).toList(growable: false);

  /// Find a feature by key.
  static FeatureDef? byKey(String key) {
    for (final f in features) {
      if (f.key == key) return f;
    }
    return null;
  }
}
