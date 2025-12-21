// lib/core/tenancy/models/feature_keys.dart

/// Central registry of tenant feature keys.
/// Use these constants instead of hard-coded strings.
abstract class FeatureKeys {
  const FeatureKeys._();

  // ───────── Foundation / platform ─────────

  static const String core = 'core';
  static const String hq = 'hq';
  static const String multiTenant = 'multiTenant';

  // ───────── Inventory / operations ─────────

  static const String inventory = 'inventory';

  static const String inventoryItems = 'inventory.items';
  static const String inventoryLocations = 'inventory.locations';
  static const String inventoryImport = 'inventory.import';
  static const String inventoryPreferences = 'inventory.preferences';
  static const String inventoryRecords = 'inventory.records';
  static const String inventoryReports = 'inventory.reports';
  static const String inventoryReorder = 'inventory.reorder';
  static const String inventoryIssues = 'inventory.issues';
  static const String inventoryViews = 'inventory.views';

  // ───────── Retail ─────────

  static const String retail = 'retail';
  static const String retailCatalog = 'retail.catalog';
  static const String retailCheckout = 'retail.checkout';

  // ───────── Clinical ─────────

  static const String dispensing = 'dispensing';
  static const String labs = 'labs';
  static const String clinicalRecords = 'clinical.records';

  // ───────── Billing / finance ─────────

  static const String billing = 'billing';
  static const String billingIntegrations = 'billing.integrations';

  // ───────── Communication ─────────

  static const String messaging = 'messaging';
  static const String messagingTransactional = 'messaging.transactional';
  static const String messagingMarketing = 'messaging.marketing';

  // ───────── Reporting / analytics ─────────

  static const String reporting = 'reporting';
  static const String reportingExports = 'reporting.exports';

  // ───────── Misc / future ─────────

  static const String beta = 'beta';
  static const String internalTools = 'internal.tools';
}
