// lib/core/capabilities/feature_keys.dart

abstract final class FeatureKeys {
  const FeatureKeys._();

  // ─────────────────────────────────────────
  // Platform
  // ─────────────────────────────────────────

  static const String core = 'core';
  static const String hq = 'hq';
  static const String backup = 'backup';

  // ─────────────────────────────────────────
  // Healthcare
  // ─────────────────────────────────────────

  static const String clinical = 'clinical';
  static const String healthTracking = 'health_tracking';
  static const String diagnostics = 'diagnostics';
  static const String pharmacy = 'pharmacy';
  static const String occupationalHealth = 'occupational_health';
  static const String insurance = 'insurance';

  // ─────────────────────────────────────────
  // Commerce and operations
  // ─────────────────────────────────────────

  static const String retail = 'retail';
  static const String inventory = 'inventory';
  static const String rider = 'rider';

  // ─────────────────────────────────────────
  // Shared services
  // ─────────────────────────────────────────

  static const String messaging = 'messaging';
  static const String reporting = 'reporting';
}
