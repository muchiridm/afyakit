// lib/features/home/registry/home_registry.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/providers/app_profile_providers.dart';

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/capabilities/feature_keys.dart';
import 'package:afyakit/core/capabilities/feature_registry.dart';

import 'package:afyakit/features/admin/widgets/admin_dashboard_screen.dart';
import 'package:afyakit/features/home/models/staff_feature_def.dart';

import 'package:afyakit/features/insurance/claim_packs/widgets/insurance_claims_screen.dart';
import 'package:afyakit/features/insurance/memberships/widgets/insurance_memberships_screen.dart';

import 'package:afyakit/features/inventory/records/shared/records_dashboard_screen.dart';
import 'package:afyakit/features/inventory/reports/screens/stock_report_screen.dart';
import 'package:afyakit/features/inventory/views/screens/stock_screen.dart';
import 'package:afyakit/features/inventory/views/utils/inventory_mode_enum.dart';

import 'package:afyakit/features/records/health_metrics/widgets/health_metrics_dashboard_screen.dart';
import 'package:afyakit/features/records/profiles/widgets/profiles_screen.dart';

import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';
import 'package:afyakit/features/retail/contacts/widgets/contacts_screen.dart';
import 'package:afyakit/features/retail/invoices/widgets/invoices_list_screen.dart';
import 'package:afyakit/features/retail/quotes/widgets/quotes_list_screen.dart';
import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';

enum HomeScope { staff, member }

final class HomeRegistry {
  const HomeRegistry._();

  // ─────────────────────────────────────────────
  // Feature tiles
  // ─────────────────────────────────────────────

  static List<StaffFeatureDef> featureTiles(
    WidgetRef ref,
    AuthUser user, {
    required HomeScope scope,
  }) {
    final appProfile = ref.watch(appProfileProvider).valueOrNull;

    final actions = _visibleActions(ref, user, scope);

    final tiles = <StaffFeatureDef>[];

    for (final feature in FeatureRegistry.features) {
      // Admin is permission-controlled, not capability-controlled.
      if (feature.key == FeatureKeys.hq) continue;

      final definition = StaffFeatureDef(
        featureKey: feature.key,
        destination: feature.entry,
      );

      if (!_isVisibleForApp(appProfile, definition)) continue;

      if (!_isAllowedForScope(ref, user, definition, scope)) {
        continue;
      }

      final hasActions = actions.any(
        (action) => action.featureKey == feature.key,
      );

      if (definition.destination == null && !hasActions) {
        continue;
      }

      tiles.add(definition);
    }

    // HQ remains available to authorised staff regardless
    // of the active application's configured capabilities.
    if (scope == HomeScope.staff && user.canAccessAdminPanel) {
      tiles.add(
        const StaffFeatureDef(
          featureKey: FeatureKeys.hq,
          labelOverride: 'Admin',
          iconOverride: Icons.admin_panel_settings,
          destination: _admin,
          allowed: _canAccessAdmin,
          enabledByTenantFeature: false,
        ),
      );
    }

    return List<StaffFeatureDef>.unmodifiable(tiles);
  }

  // ─────────────────────────────────────────────
  // Quick actions
  // ─────────────────────────────────────────────

  static List<StaffFeatureDef> quickActions(
    WidgetRef ref,
    AuthUser user, {
    required HomeScope scope,
  }) {
    return List<StaffFeatureDef>.unmodifiable(
      _visibleActions(ref, user, scope),
    );
  }

  static List<StaffFeatureDef> actionsFor(
    WidgetRef ref,
    AuthUser user,
    String featureKey, {
    required HomeScope scope,
  }) {
    final key = featureKey.trim().toLowerCase();

    if (key.isEmpty) {
      return const <StaffFeatureDef>[];
    }

    return List<StaffFeatureDef>.unmodifiable(
      _visibleActions(
        ref,
        user,
        scope,
      ).where((action) => action.featureKey.trim().toLowerCase() == key),
    );
  }

  static List<StaffFeatureDef> _visibleActions(
    WidgetRef ref,
    AuthUser user,
    HomeScope scope,
  ) {
    final appProfile = ref.watch(appProfileProvider).valueOrNull;

    return _actionsForScope(scope)
        .where((action) => _isVisibleForApp(appProfile, action))
        .where((action) => _isAllowedForScope(ref, user, action, scope))
        .toList(growable: false);
  }

  static List<StaffFeatureDef> _actionsForScope(HomeScope scope) {
    return switch (scope) {
      HomeScope.staff => _staffQuickActions,
      HomeScope.member => _memberQuickActions,
    };
  }

  // ─────────────────────────────────────────────
  // Staff quick actions
  // ─────────────────────────────────────────────

  static const List<StaffFeatureDef> _staffQuickActions = [
    // Core Records
    StaffFeatureDef(
      featureKey: FeatureKeys.core,
      labelOverride: 'Health Profiles',
      iconOverride: Icons.people_alt_outlined,
      destination: _healthProfiles,
      allowed: _requireStaff,
    ),

    StaffFeatureDef(
      featureKey: FeatureKeys.core,
      labelOverride: 'Health Metrics',
      iconOverride: Icons.monitor_heart_outlined,
      destination: _healthMetrics,
      allowed: _requireStaff,
    ),

    // Clinical
    StaffFeatureDef(
      featureKey: FeatureKeys.clinical,
      labelOverride: 'Prescriptions',
      iconOverride: Icons.description_outlined,
      allowed: _requireStaff,
    ),

    // Retail
    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'Contacts',
      iconOverride: Icons.people_alt_outlined,
      destination: _contacts,
      allowedRef: _allowRetailForApp,
    ),

    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'Catalog',
      iconOverride: Icons.apps,
      destination: _catalog,
      allowedRef: _allowRetailForApp,
    ),

    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'Quotes',
      iconOverride: Icons.request_quote_outlined,
      destination: _quotes,
      allowedRef: _allowRetailForApp,
    ),

    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'Invoices and Payments',
      iconOverride: Icons.receipt_outlined,
      destination: _invoices,
      allowedRef: _allowRetailForApp,
    ),

    // Insurance
    StaffFeatureDef(
      featureKey: FeatureKeys.insurance,
      labelOverride: 'Insurance Memberships',
      iconOverride: Icons.verified_user_outlined,
      destination: _insuranceMemberships,
      allowedRef: _allowInsuranceForApp,
    ),

    StaffFeatureDef(
      featureKey: FeatureKeys.insurance,
      labelOverride: 'Insurance Claims',
      iconOverride: Icons.assignment_outlined,
      destination: _insuranceClaims,
      allowedRef: _allowInsuranceForApp,
    ),

    // Inventory
    StaffFeatureDef(
      featureKey: FeatureKeys.inventory,
      labelOverride: 'Stock In',
      iconOverride: Icons.inventory,
      destination: _stockIn,
      allowed: _requireStaff,
    ),

    StaffFeatureDef(
      featureKey: FeatureKeys.inventory,
      labelOverride: 'Stock Out',
      iconOverride: Icons.exit_to_app,
      destination: _stockOut,
      allowed: _requireStaff,
    ),

    StaffFeatureDef(
      featureKey: FeatureKeys.inventory,
      labelOverride: 'Inventory Records',
      iconOverride: Icons.history,
      destination: _inventoryRecords,
      allowed: _requireStaff,
    ),

    StaffFeatureDef(
      featureKey: FeatureKeys.inventory,
      labelOverride: 'Stock Report',
      iconOverride: Icons.inventory_2_outlined,
      destination: _stockReport,
      allowed: _requireStaff,
    ),

    // Platform administration
    StaffFeatureDef(
      featureKey: FeatureKeys.hq,
      labelOverride: 'Admin',
      iconOverride: Icons.admin_panel_settings,
      destination: _admin,
      allowed: _canAccessAdmin,
      enabledByTenantFeature: false,
    ),
  ];

  // ─────────────────────────────────────────────
  // Member quick actions
  // ─────────────────────────────────────────────

  static const List<StaffFeatureDef> _memberQuickActions = [
    // Core Records
    StaffFeatureDef(
      featureKey: FeatureKeys.core,
      labelOverride: 'My Profiles',
      iconOverride: Icons.people_alt_outlined,
      destination: _myProfiles,
      allowed: _requireMember,
    ),

    StaffFeatureDef(
      featureKey: FeatureKeys.core,
      labelOverride: 'My Health Metrics',
      iconOverride: Icons.monitor_heart_outlined,
      destination: _healthMetrics,
      allowed: _requireMember,
    ),

    // Clinical
    StaffFeatureDef(
      featureKey: FeatureKeys.clinical,
      labelOverride: 'My Prescriptions',
      iconOverride: Icons.description_outlined,
      allowedRef: _allowMemberClinical,
    ),

    // Retail
    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'Catalog',
      iconOverride: Icons.apps,
      destination: _catalog,
      allowedRef: _allowRetailForApp,
    ),

    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'My Quotes',
      iconOverride: Icons.request_quote_outlined,
      destination: _myQuotes,
      allowedRef: _allowRetailForApp,
    ),

    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'My Invoices and Payments',
      iconOverride: Icons.receipt_outlined,
      destination: _myInvoices,
      allowedRef: _allowRetailForApp,
    ),
  ];

  // ─────────────────────────────────────────────
  // Destinations
  // ─────────────────────────────────────────────

  static Widget _healthProfiles(BuildContext _) =>
      const ProfilesScreen(allowExplicitContactLink: true);

  static Widget _myProfiles(BuildContext _) => const ProfilesScreen();

  static Widget _healthMetrics(BuildContext _) =>
      const HealthMetricsDashboardScreen();

  static Widget _contacts(BuildContext _) => const ContactsScreen();

  static Widget _catalog(BuildContext _) => const CatalogScreen();

  static Widget _quotes(BuildContext _) => const QuotesListScreen();

  static Widget _invoices(BuildContext _) => const InvoicesListScreen();

  static Widget _myQuotes(BuildContext _) =>
      const QuotesListScreen(scope: RetailDocScope.mine);

  static Widget _myInvoices(BuildContext _) =>
      const InvoicesListScreen(scope: RetailDocScope.mine);

  static Widget _insuranceMemberships(BuildContext _) =>
      const InsuranceMembershipsScreen();

  static Widget _insuranceClaims(BuildContext _) =>
      const InsuranceClaimsScreen();

  static Widget _stockIn(BuildContext _) =>
      const StockScreen(mode: InventoryMode.stockIn);

  static Widget _stockOut(BuildContext _) =>
      const StockScreen(mode: InventoryMode.stockOut);

  static Widget _inventoryRecords(BuildContext _) =>
      const RecordsDashboardScreen();

  static Widget _stockReport(BuildContext _) => const StockReportScreen();

  static Widget _admin(BuildContext _) => const AdminDashboardScreen();

  // ─────────────────────────────────────────────
  // Access checks
  // ─────────────────────────────────────────────

  static bool _requireStaff(AuthUser user) => user.isStaff;

  static bool _requireMember(AuthUser user) => !user.isStaffResolved;

  static bool _canAccessAdmin(AuthUser user) => user.canAccessAdminPanel;

  static bool _allowRetailForApp(WidgetRef ref, AuthUser _) {
    final profile = ref.watch(appProfileProvider).valueOrNull;

    return profile?.features.enabled(FeatureKeys.retail) == true;
  }

  static bool _allowInsuranceForApp(WidgetRef ref, AuthUser user) {
    if (!user.isStaff) return false;

    final profile = ref.watch(appProfileProvider).valueOrNull;

    return profile?.features.enabled(FeatureKeys.insurance) == true;
  }

  static bool _allowMemberClinical(WidgetRef ref, AuthUser user) {
    if (!_requireMember(user)) return false;

    final profile = ref.watch(appProfileProvider).valueOrNull;

    return profile?.features.enabled(FeatureKeys.clinical) == true;
  }

  // ─────────────────────────────────────────────
  // Scope visibility
  // ─────────────────────────────────────────────

  static bool _isAllowedForScope(
    WidgetRef ref,
    AuthUser user,
    StaffFeatureDef definition,
    HomeScope scope,
  ) {
    if (scope == HomeScope.member) {
      // Only explicitly defined member actions are exposed.
      // A general feature entry is not sufficient.
      if (!_memberQuickActions.contains(definition)) {
        return false;
      }
    }

    final allowed = definition.allowed;

    if (allowed != null && !allowed(user)) {
      return false;
    }

    final allowedRef = definition.allowedRef;

    if (allowedRef != null && !allowedRef(ref, user)) {
      return false;
    }

    return true;
  }

  // ─────────────────────────────────────────────
  // Application capability visibility
  // ─────────────────────────────────────────────

  static bool _isVisibleForApp(dynamic profile, StaffFeatureDef definition) {
    // HQ is permission-controlled rather than app-configured.
    if (definition.enabledByTenantFeature == false) {
      return true;
    }

    final key = definition.featureKey.trim().toLowerCase();

    if (key.isEmpty) {
      return false;
    }

    // Core Records is mandatory.
    if (key == FeatureKeys.core) {
      return true;
    }

    // Optional capabilities require an active app profile.
    if (profile == null) {
      return false;
    }

    return profile.features.enabled(key);
  }
}
