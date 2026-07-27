// lib/core/home/registry/home_registry.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/home/models/staff_feature_def.dart';
import 'package:afyakit/core/home/widgets/shared/admin_dashboard/admin_dashboard_screen.dart';
import 'package:afyakit/core/hq/tenants/models/feature_keys.dart';
import 'package:afyakit/core/hq/tenants/models/feature_registry.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_profile_providers.dart';

import 'package:afyakit/features/clinical/profiles/widgets/profiles_screen.dart';
import 'package:afyakit/features/health_metrics/widgets/health_metrics_dashboard_screen.dart';
import 'package:afyakit/features/insurance/claim_packs/widgets/insurance_claims_screen.dart';
import 'package:afyakit/features/insurance/memberships/widgets/insurance_memberships_screen.dart';
import 'package:afyakit/features/inventory/records/shared/records_dashboard_screen.dart';
import 'package:afyakit/features/inventory/reports/screens/stock_report_screen.dart';
import 'package:afyakit/features/inventory/views/screens/stock_screen.dart';
import 'package:afyakit/features/inventory/views/utils/inventory_mode_enum.dart';
import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';
import 'package:afyakit/features/retail/contacts/widgets/contacts_screen.dart';
import 'package:afyakit/features/retail/invoices/widgets/invoices_list_screen.dart';
import 'package:afyakit/features/retail/quotes/widgets/quotes_list_screen.dart';
import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';

enum HomeScope { staff, member }

final class HomeRegistry {
  const HomeRegistry._();

  static const StaffFeatureDef _messagingFeatureTile = StaffFeatureDef(
    featureKey: FeatureKeys.messaging,
    labelOverride: 'Messaging',
    iconOverride: Icons.chat_bubble_outline_rounded,
    enabledByTenantFeature: false,
  );

  static List<StaffFeatureDef> featureTiles(
    WidgetRef ref,
    AuthUser user, {
    required HomeScope scope,
  }) {
    final profile = ref.watch(tenantProfileProvider).valueOrNull;

    final registryTiles = FeatureRegistry.features
        .map(
          (feature) => StaffFeatureDef(
            featureKey: feature.key,
            destination: feature.entry,
          ),
        )
        .where((definition) => _isVisibleForTenant(profile, definition))
        .where((definition) => _isAllowedForScope(ref, user, definition, scope))
        .toList(growable: true);

    if (scope == HomeScope.staff && _shouldShowMessagingTile(ref, user)) {
      final alreadyHasMessaging = registryTiles.any(
        (definition) =>
            definition.featureKey.trim().toLowerCase() == FeatureKeys.messaging,
      );

      if (!alreadyHasMessaging) {
        registryTiles.add(_messagingFeatureTile);
      }
    }

    return registryTiles.toList(growable: false);
  }

  static bool _shouldShowMessagingTile(WidgetRef ref, AuthUser user) {
    final profile = ref.watch(tenantProfileProvider).valueOrNull;

    return _staffQuickActions
        .where((definition) => definition.featureKey == FeatureKeys.messaging)
        .where((definition) => _isVisibleForTenant(profile, definition))
        .where(
          (definition) =>
              _isAllowedForScope(ref, user, definition, HomeScope.staff),
        )
        .isNotEmpty;
  }

  static List<StaffFeatureDef> quickActions(
    WidgetRef ref,
    AuthUser user, {
    required HomeScope scope,
  }) {
    final profile = ref.watch(tenantProfileProvider).valueOrNull;
    final actions = _actionsForScope(scope);

    return actions
        .where((definition) => _isVisibleForTenant(profile, definition))
        .where((definition) => _isAllowedForScope(ref, user, definition, scope))
        .toList(growable: false);
  }

  static List<StaffFeatureDef> actionsFor(
    WidgetRef ref,
    AuthUser user,
    String featureKey, {
    required HomeScope scope,
  }) {
    final normalizedKey = featureKey.trim().toLowerCase();

    return quickActions(ref, user, scope: scope)
        .where(
          (action) => action.featureKey.trim().toLowerCase() == normalizedKey,
        )
        .toList(growable: false);
  }

  static List<StaffFeatureDef> _actionsForScope(HomeScope scope) {
    switch (scope) {
      case HomeScope.staff:
        return _staffQuickActions;

      case HomeScope.member:
        return _memberQuickActions;
    }
  }

  static const List<StaffFeatureDef> _staffQuickActions = [
    // ─────────────────────────────────────────────
    // Health Metrics
    // ─────────────────────────────────────────────
    StaffFeatureDef(
      featureKey: FeatureKeys.healthMetrics,
      labelOverride: 'Health Metrics',
      iconOverride: Icons.monitor_heart_outlined,
      destination: _healthMetrics,
      allowed: _requireStaff,
    ),

    // ─────────────────────────────────────────────
    // Clinical
    // ─────────────────────────────────────────────
    StaffFeatureDef(
      featureKey: FeatureKeys.clinical,
      labelOverride: 'Patient Profiles',
      iconOverride: Icons.people_alt_outlined,
      destination: _patientProfiles,
      allowed: _requireStaff,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.clinical,
      labelOverride: 'Prescriptions',
      iconOverride: Icons.description_outlined,
      allowed: _requireStaff,
    ),

    // ─────────────────────────────────────────────
    // Messaging
    // ─────────────────────────────────────────────
    StaffFeatureDef(
      featureKey: FeatureKeys.messaging,
      labelOverride: 'Contacts',
      iconOverride: Icons.people_alt,
      destination: _contacts,
      allowedRef: _allowRetailForTenant,
      enabledByTenantFeature: false,
    ),

    // ─────────────────────────────────────────────
    // Retail
    // ─────────────────────────────────────────────
    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'Catalog',
      iconOverride: Icons.apps,
      destination: _catalog,
      allowedRef: _allowRetailForTenant,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'Quotes',
      iconOverride: Icons.request_quote_outlined,
      destination: _quotes,
      allowedRef: _allowRetailForTenant,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'Invoices and Payments',
      iconOverride: Icons.receipt_outlined,
      destination: _invoices,
      allowedRef: _allowRetailForTenant,
    ),

    // ─────────────────────────────────────────────
    // Insurance
    // ─────────────────────────────────────────────
    StaffFeatureDef(
      featureKey: FeatureKeys.insurance,
      labelOverride: 'Insurance Memberships',
      iconOverride: Icons.verified_user_outlined,
      destination: _insuranceMemberships,
      allowedRef: _allowInsuranceForTenant,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.insurance,
      labelOverride: 'Insurance Claims',
      iconOverride: Icons.assignment_outlined,
      destination: _insuranceClaims,
      allowedRef: _allowInsuranceForTenant,
    ),

    // ─────────────────────────────────────────────
    // Inventory
    // ─────────────────────────────────────────────
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
      labelOverride: 'Records',
      iconOverride: Icons.history,
      destination: _records,
      allowed: _requireStaff,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.inventory,
      labelOverride: 'Stock Report',
      iconOverride: Icons.inventory_2_outlined,
      destination: _stockReport,
      allowed: _requireStaff,
    ),

    // ─────────────────────────────────────────────
    // Admin
    // ─────────────────────────────────────────────
    StaffFeatureDef(
      featureKey: FeatureKeys.hq,
      labelOverride: 'Admin',
      iconOverride: Icons.admin_panel_settings,
      destination: _admin,
      allowed: _canAccessAdmin,
      enabledByTenantFeature: false,
    ),
  ];

  static const List<StaffFeatureDef> _memberQuickActions = [
    // ─────────────────────────────────────────────
    // Health Metrics
    // ─────────────────────────────────────────────
    StaffFeatureDef(
      featureKey: FeatureKeys.healthMetrics,
      labelOverride: 'My Health Metrics',
      iconOverride: Icons.monitor_heart_outlined,
      destination: _healthMetrics,
      allowedRef: _allowMemberHealthMetrics,
    ),

    // ─────────────────────────────────────────────
    // Clinical
    // ─────────────────────────────────────────────
    StaffFeatureDef(
      featureKey: FeatureKeys.clinical,
      labelOverride: 'My Profiles',
      iconOverride: Icons.people_alt_outlined,
      destination: _myProfiles,
      allowedRef: _allowMemberClinical,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.clinical,
      labelOverride: 'My Prescriptions',
      iconOverride: Icons.description_outlined,
      allowedRef: _allowMemberClinical,
    ),

    // ─────────────────────────────────────────────
    // Retail
    // ─────────────────────────────────────────────
    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'Catalog',
      iconOverride: Icons.apps,
      destination: _catalog,
      allowedRef: _allowRetailForTenant,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'My Quotes',
      iconOverride: Icons.request_quote_outlined,
      destination: _myQuotes,
      allowedRef: _allowRetailForTenant,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'My Invoices and Payments',
      iconOverride: Icons.receipt_outlined,
      destination: _myInvoices,
      allowedRef: _allowRetailForTenant,
    ),
  ];

  static Widget _healthMetrics(BuildContext _) {
    return const HealthMetricsDashboardScreen();
  }

  static Widget _stockIn(BuildContext _) {
    return const StockScreen(mode: InventoryMode.stockIn);
  }

  static Widget _stockOut(BuildContext _) {
    return const StockScreen(mode: InventoryMode.stockOut);
  }

  static Widget _records(BuildContext _) {
    return const RecordsDashboardScreen();
  }

  static Widget _stockReport(BuildContext _) {
    return const StockReportScreen();
  }

  static Widget _admin(BuildContext _) {
    return const AdminDashboardScreen();
  }

  static Widget _contacts(BuildContext _) {
    return const ContactsScreen();
  }

  static Widget _catalog(BuildContext _) {
    return const CatalogScreen();
  }

  static Widget _quotes(BuildContext _) {
    return const QuotesListScreen();
  }

  static Widget _invoices(BuildContext _) {
    return const InvoicesListScreen();
  }

  static Widget _patientProfiles(BuildContext _) {
    return const ProfilesScreen(allowExplicitContactLink: true);
  }

  static Widget _insuranceMemberships(BuildContext _) {
    return const InsuranceMembershipsScreen();
  }

  static Widget _insuranceClaims(BuildContext _) {
    return const InsuranceClaimsScreen();
  }

  static Widget _myProfiles(BuildContext _) {
    return const ProfilesScreen();
  }

  static Widget _myQuotes(BuildContext _) {
    return const QuotesListScreen(scope: RetailDocScope.mine);
  }

  static Widget _myInvoices(BuildContext _) {
    return const InvoicesListScreen(scope: RetailDocScope.mine);
  }

  static bool _requireStaff(AuthUser user) {
    return user.isStaff;
  }

  static bool _canAccessAdmin(AuthUser user) {
    return user.canAccessAdminPanel;
  }

  static bool _allowRetailForTenant(WidgetRef ref, AuthUser _) {
    final profile = ref.watch(tenantProfileProvider).valueOrNull;

    return profile?.features.enabled(FeatureKeys.retail) == true;
  }

  static bool _allowInsuranceForTenant(WidgetRef ref, AuthUser user) {
    if (!user.isStaff) return false;

    final profile = ref.watch(tenantProfileProvider).valueOrNull;

    return profile?.features.enabled(FeatureKeys.insurance) == true;
  }

  static bool _allowMemberHealthMetrics(WidgetRef ref, AuthUser user) {
    if (user.isStaffResolved) return false;

    final profile = ref.watch(tenantProfileProvider).valueOrNull;

    return profile?.features.enabled(FeatureKeys.healthMetrics) == true;
  }

  static bool _allowMemberClinical(WidgetRef ref, AuthUser user) {
    if (user.isStaffResolved) return false;

    final accountNumber = (user.accountNumber ?? '').trim();
    if (accountNumber.isEmpty) return false;

    final profile = ref.watch(tenantProfileProvider).valueOrNull;

    return profile?.features.enabled(FeatureKeys.clinical) == true;
  }

  static bool _isAllowedForScope(
    WidgetRef ref,
    AuthUser user,
    StaffFeatureDef definition,
    HomeScope scope,
  ) {
    if (scope == HomeScope.member) {
      final featureKey = definition.featureKey;

      if (featureKey == FeatureKeys.inventory) return false;
      if (featureKey == FeatureKeys.insurance) return false;
      if (featureKey == FeatureKeys.reporting) return false;
      if (featureKey == FeatureKeys.hq) return false;
      if (featureKey == FeatureKeys.rider) return false;
      if (featureKey == FeatureKeys.backup) return false;

      if (featureKey == FeatureKeys.healthMetrics &&
          definition.destination != _healthMetrics) {
        return false;
      }

      if (featureKey == FeatureKeys.clinical &&
          definition.destination != _myProfiles &&
          definition.label.trim().toLowerCase() != 'my prescriptions') {
        return false;
      }
    }

    final allowed = definition.allowed;
    if (allowed != null && !allowed(user)) return false;

    final allowedRef = definition.allowedRef;
    if (allowedRef != null && !allowedRef(ref, user)) return false;

    return true;
  }

  static bool _isVisibleForTenant(dynamic profile, StaffFeatureDef definition) {
    if (definition.enabledByTenantFeature == false) return true;
    if (profile == null) return false;

    final featureKey = definition.featureKey.trim();
    if (featureKey.isEmpty) return false;

    return profile.features.enabled(featureKey);
  }
}
