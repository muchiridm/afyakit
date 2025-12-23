/// Central registry of module feature keys (ROOT MODULES ONLY).
/// Keep this intentionally small and stable.
///
/// Tenants store these as:
///   features: { inventory: true, retail: false, ... }
abstract class FeatureKeys {
  const FeatureKeys._();

  // ───────── Platform / admin ─────────

  /// Core app foundation (usually assumed ON; optional to store in Firestore)
  static const String core = 'core';

  /// HQ admin module / HQ access
  static const String hq = 'hq';

  // ───────── Business modules ─────────

  static const String inventory = 'inventory';
  static const String retail = 'retail';

  static const String dispensing = 'dispensing';
  static const String labs = 'labs';
  static const String consultation = 'consultation';

  static const String rider = 'rider';

  // ───────── Optional / future ─────────

  static const String reporting = 'reporting';
  static const String messaging = 'messaging';
  static const String backup = 'backup';
}
