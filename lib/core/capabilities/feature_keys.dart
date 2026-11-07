// lib/core/capabilities/feature_keys.dart

abstract final class FeatureKeys {
  const FeatureKeys._();

  // Platform services shared across applications.
  static const String core = 'core';
  static const String hq = 'hq';
  static const String backup = 'backup';

  // Healthcare and health-related capabilities.
  // Tests are part of Clinical, not a standalone application capability.
  static const String clinical = 'clinical';
  static const String healthMonitoring = 'health_monitoring';
  static const String pharmacy = 'pharmacy';
  static const String occupationalHealth = 'occupational_health';
  static const String insurance = 'insurance';

  // Commerce and operations.
  static const String retail = 'retail';
  static const String inventory = 'inventory';
  static const String rider = 'rider';

  // Shared services.
  static const String messaging = 'messaging';
  static const String reporting = 'reporting';
}
