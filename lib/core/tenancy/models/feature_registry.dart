import 'package:flutter/material.dart';

import 'feature_keys.dart';

/// A single "module" (feature) that can be toggled per tenant.
///
/// Keep it simple:
/// - key = stored in tenant.features map
/// - label/icon/description = used for HQ editor + staff module tiles
/// - entry is optional: wire a module home screen when ready
@immutable
class ModuleDef {
  final String key;
  final String label;
  final IconData icon;
  final String? description;

  /// Optional: staff module home screen builder.
  /// If null, module can still be enabled, but navigation should be guarded by the UI.
  final WidgetBuilder? entry;

  const ModuleDef({
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

  /// All modules that can appear in HQ tenant editor / staff module tiles.
  static const List<ModuleDef> modules = <ModuleDef>[
    // Platform / admin
    ModuleDef(
      key: FeatureKeys.hq,
      label: 'HQ',
      icon: Icons.admin_panel_settings_outlined,
      description: 'Admin console for managing tenants and users.',
    ),

    // Core business modules
    ModuleDef(
      key: FeatureKeys.inventory,
      label: 'Inventory',
      icon: Icons.inventory_2_outlined,
      description: 'Stock items, batches, locations, reports, reorder.',
    ),
    ModuleDef(
      key: FeatureKeys.retail,
      label: 'Retail',
      icon: Icons.storefront_outlined,
      description: 'Catalog, carts, orders, payments, delivery.',
    ),

    // Clinical
    ModuleDef(
      key: FeatureKeys.dispensing,
      label: 'Dispensing',
      icon: Icons.medical_services_outlined,
      description: 'Upload and verify prescriptions; dispense workflow.',
    ),
    ModuleDef(
      key: FeatureKeys.labs,
      label: 'Labs',
      icon: Icons.science_outlined,
      description: 'Lab requests, results, and reporting.',
    ),
    ModuleDef(
      key: FeatureKeys.consultation,
      label: 'Consultation',
      icon: Icons.video_call_outlined,
      description: 'Provider consultations and notes.',
    ),

    // Logistics
    ModuleDef(
      key: FeatureKeys.rider,
      label: 'Rider',
      icon: Icons.delivery_dining_outlined,
      description: 'Deliveries, rider jobs, tracking, confirmations.',
    ),

    // Optional / future
    ModuleDef(
      key: FeatureKeys.reporting,
      label: 'Reporting',
      icon: Icons.bar_chart_outlined,
      description: 'Analytics dashboards and exports.',
    ),
    ModuleDef(
      key: FeatureKeys.messaging,
      label: 'Messaging',
      icon: Icons.chat_bubble_outline,
      description: 'Customer and staff messaging / notifications.',
    ),
    ModuleDef(
      key: FeatureKeys.backup,
      label: 'Backup',
      icon: Icons.cloud_upload_outlined,
      description: 'Backups, exports, and recovery utilities.',
    ),
  ];

  /// Convenience: keys only (useful for editors/validation).
  static List<String> get keys =>
      modules.map((m) => m.key).toList(growable: false);

  /// Find a module by key.
  static ModuleDef? byKey(String key) {
    for (final m in modules) {
      if (m.key == key) return m;
    }
    return null;
  }
}
