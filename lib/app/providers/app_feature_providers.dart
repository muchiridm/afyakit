import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/capabilities/feature_keys.dart';

/// Whether a capability is available in the active application.
///
/// Core is mandatory and includes shared identity, Native Contacts,
/// Health Profiles and common records infrastructure.
///
/// All optional capabilities are resolved from the application's
/// AppProfile, never from tenant-wide configuration.
///
/// Health Monitoring is independent of Clinical.
/// Tests belong to Clinical and do not require a separate capability.
final isAppFeatureEnabledProvider = Provider.autoDispose.family<bool, String>((
  ref,
  key,
) {
  final normalizedKey = key.trim().toLowerCase();

  if (normalizedKey.isEmpty) {
    return false;
  }

  // Core is intrinsic to every application.
  if (normalizedKey == FeatureKeys.core) {
    return true;
  }

  final appAsync = ref.watch(appProfileProvider);

  return appAsync.when(
    loading: () => false,
    error: (_, __) => false,
    data: (app) => app.features.enabled(normalizedKey),
  );
});

// ─────────────────────────────────────────
// Platform
// ─────────────────────────────────────────

final appCoreEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isAppFeatureEnabledProvider(FeatureKeys.core));
});

final appHqEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isAppFeatureEnabledProvider(FeatureKeys.hq));
});

final appBackupEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isAppFeatureEnabledProvider(FeatureKeys.backup));
});

// ─────────────────────────────────────────
// Healthcare
// ─────────────────────────────────────────

final appClinicalEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isAppFeatureEnabledProvider(FeatureKeys.clinical));
});

/// Longitudinal health metrics, wellness measurements,
/// monitoring and trends.
///
/// Independent of Clinical. Afya Tracker is a primary
/// consumer, but other applications may enable it.
final appHealthMonitoringEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isAppFeatureEnabledProvider(FeatureKeys.healthMonitoring));
});

final appPharmacyEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isAppFeatureEnabledProvider(FeatureKeys.pharmacy));
});

final appOccupationalHealthEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isAppFeatureEnabledProvider(FeatureKeys.occupationalHealth));
});

final appInsuranceEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isAppFeatureEnabledProvider(FeatureKeys.insurance));
});

// ─────────────────────────────────────────
// Commerce and operations
// ─────────────────────────────────────────

final appRetailEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isAppFeatureEnabledProvider(FeatureKeys.retail));
});

final appInventoryEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isAppFeatureEnabledProvider(FeatureKeys.inventory));
});

final appRiderEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isAppFeatureEnabledProvider(FeatureKeys.rider));
});

// ─────────────────────────────────────────
// Shared services
// ─────────────────────────────────────────

final appMessagingEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isAppFeatureEnabledProvider(FeatureKeys.messaging));
});

final appReportingEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(isAppFeatureEnabledProvider(FeatureKeys.reporting));
});

// ─────────────────────────────────────────
// Product UX helpers
// ─────────────────────────────────────────

/// Whether the current application exposes a member-facing experience.
///
/// Core Records alone does not imply a public/member-facing UI.
///
/// Clinical patients, wellness members, employees, pharmacy customers,
/// and insured members may have different experiences depending on
/// the active application's capabilities.
final appMemberUxEnabledProvider = Provider.autoDispose<bool>((ref) {
  final clinical = ref.watch(appClinicalEnabledProvider);
  final healthMonitoring = ref.watch(appHealthMonitoringEnabledProvider);
  final pharmacy = ref.watch(appPharmacyEnabledProvider);
  final occupationalHealth = ref.watch(appOccupationalHealthEnabledProvider);
  final insurance = ref.watch(appInsuranceEnabledProvider);
  final retail = ref.watch(appRetailEnabledProvider);

  return clinical ||
      healthMonitoring ||
      pharmacy ||
      occupationalHealth ||
      insurance ||
      retail;
});
