// lib/core/hq/tenants/models/feature_keys.dart

abstract class FeatureKeys {
  const FeatureKeys._();

  // ───────── Platform / admin ─────────
  static const String core = 'core';
  static const String hq = 'hq';

  // ───────── Main module groups ─────────
  static const String inventory = 'inventory';
  static const String retail = 'retail';
  static const String clinical = 'clinical';
  static const String insurance = 'insurance';
  static const String rider = 'rider';
  static const String healthMetrics = 'health_metrics';

  // ───────── Optional / future groups ─────────
  static const String reporting = 'reporting';
  static const String messaging = 'messaging';
  static const String backup = 'backup';
}
