import 'package:afyakit/core/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/core/tenancy/models/feature_keys.dart';
import 'package:afyakit/core/tenancy/models/feature_registry.dart';
import 'package:afyakit/core/tenancy/providers/tenant_profile_providers.dart';
import 'package:afyakit/features/inventory/records/shared/records_dashboard_screen.dart';
import 'package:afyakit/features/inventory/reports/screens/stock_report_screen.dart';
import 'package:afyakit/features/inventory/views/screens/stock_screen.dart';
import 'package:afyakit/features/inventory/views/utils/inventory_mode_enum.dart';
import 'package:afyakit/features/retail/catalog/widgets/screens/catalog_screen.dart';
import 'package:afyakit/features/retail/contacts/widgets/contacts_screen.dart';
import 'package:afyakit/features/retail/quotes/widgets/quotes_list_screen.dart';
import 'package:afyakit/shared/home/models/staff_feature_def.dart';
import 'package:afyakit/core/auth_user/widgets/screens/admin_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class StaffHomeRegistry {
  const StaffHomeRegistry._();

  // ─────────────────────────────────────────────────────────────
  // Public API (tenancy-aware)
  // ─────────────────────────────────────────────────────────────

  static List<StaffFeatureDef> featureTiles(WidgetRef ref, AuthUser user) {
    final profile = ref.watch(tenantProfileProvider).valueOrNull;

    return FeatureRegistry.features
        .map((f) => StaffFeatureDef(featureKey: f.key, destination: f.entry))
        .where((d) => _isVisibleForTenant(profile, d))
        .where((d) => _isAllowedForUser(ref, user, d))
        .toList(growable: false);
  }

  static List<StaffFeatureDef> quickActions(WidgetRef ref, AuthUser user) {
    final profile = ref.watch(tenantProfileProvider).valueOrNull;

    return _quickActions
        .where((d) => _isVisibleForTenant(profile, d))
        .where((d) => _isAllowedForUser(ref, user, d))
        .toList(growable: false);
  }

  static List<StaffFeatureDef> actionsFor(
    WidgetRef ref,
    AuthUser user,
    String featureKey,
  ) {
    final all = quickActions(ref, user);
    return all.where((a) => a.featureKey == featureKey).toList(growable: false);
  }

  // ─────────────────────────────────────────────────────────────
  // Source of truth list for actions
  // ─────────────────────────────────────────────────────────────

  static const List<StaffFeatureDef> _quickActions = [
    // ───────── Inventory ─────────
    StaffFeatureDef(
      featureKey: FeatureKeys.inventory,
      labelOverride: 'Stock In',
      iconOverride: Icons.inventory,
      destination: _stockIn,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.inventory,
      labelOverride: 'Stock Out',
      iconOverride: Icons.exit_to_app,
      destination: _stockOut,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.inventory,
      labelOverride: 'Records',
      iconOverride: Icons.history,
      destination: _records,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.inventory,
      labelOverride: 'Stock Report',
      iconOverride: Icons.inventory_2_outlined,
      destination: _stockReport,
    ),

    // ───────── Reporting ─────────
    StaffFeatureDef(
      featureKey: FeatureKeys.reporting,
      labelOverride: 'Stock Report',
      iconOverride: Icons.inventory_2_outlined,
      destination: _stockReport,
    ),

    // ───────── Retail ─────────
    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'Catalog',
      iconOverride: Icons.apps,
      destination: _catalog,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'Contacts',
      iconOverride: Icons.people_alt,
      destination: _contacts,
      allowedRef: _allowContactsForStaffRetailTenant,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'Quotes', // ✅ NEW
      iconOverride: Icons.request_quote_outlined, // ✅ NEW
      destination: _quotes, // ✅ NEW
      allowedRef:
          _allowQuotesForStaffRetailTenant, // ✅ NEW (mirrors Contacts gate)
    ),

    // ───────── Admin (HQ) ─────────
    StaffFeatureDef(
      featureKey: FeatureKeys.hq,
      labelOverride: 'Admin',
      iconOverride: Icons.admin_panel_settings,
      destination: _admin,
      allowed: _canAccessAdmin,
      enabledByTenantFeature: false,
    ),
  ];

  // ─────────────────────────────────────────────────────────────
  // Destinations
  // ─────────────────────────────────────────────────────────────

  static Widget _stockIn(BuildContext _) =>
      const StockScreen(mode: InventoryMode.stockIn);

  static Widget _stockOut(BuildContext _) =>
      const StockScreen(mode: InventoryMode.stockOut);

  static Widget _records(BuildContext _) => const RecordsDashboardScreen();

  static Widget _stockReport(BuildContext _) => const StockReportScreen();

  static Widget _admin(BuildContext _) => const AdminDashboardScreen();

  static Widget _contacts(BuildContext _) => const ContactsScreen();

  static Widget _catalog(BuildContext _) => const CatalogScreen();

  static Widget _quotes(BuildContext _) => const QuotesListScreen(); // ✅ NEW

  // ─────────────────────────────────────────────────────────────
  // Gates
  // ─────────────────────────────────────────────────────────────

  static bool _canAccessAdmin(AuthUser u) => u.canAccessAdminPanel;

  static bool _allowContactsForStaffRetailTenant(WidgetRef ref, AuthUser u) {
    if (!u.isStaff) return false;

    final profile = ref.watch(tenantProfileProvider).valueOrNull;
    if (profile == null) return false;

    return profile.features.enabled(FeatureKeys.retail);
  }

  static bool _allowQuotesForStaffRetailTenant(WidgetRef ref, AuthUser u) {
    // same gate as contacts for now (staff + retail enabled)
    if (!u.isStaff) return false;

    final profile = ref.watch(tenantProfileProvider).valueOrNull;
    if (profile == null) return false;

    return profile.features.enabled(FeatureKeys.retail);
  }

  // ─────────────────────────────────────────────────────────────
  // Filtering helpers
  // ─────────────────────────────────────────────────────────────

  static bool _isVisibleForTenant(
    dynamic /*TenantProfile?*/ profile,
    StaffFeatureDef def,
  ) {
    if (def.enabledByTenantFeature == false) return true;
    if (profile == null) return false;

    final key = def.featureKey.trim();
    if (key.isEmpty) return false;

    return profile.features.enabled(key);
  }

  static bool _isAllowedForUser(
    WidgetRef ref,
    AuthUser user,
    StaffFeatureDef d,
  ) {
    final allowedFn = d.allowed;
    if (allowedFn != null && !allowedFn(user)) return false;

    final allowedRefFn = d.allowedRef;
    if (allowedRefFn != null && !allowedRefFn(ref, user)) return false;

    return true;
  }
}
