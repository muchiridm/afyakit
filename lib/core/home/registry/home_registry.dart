// lib/core/home/registry/home_registry.dart

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/hq/tenants/models/feature_keys.dart';
import 'package:afyakit/core/hq/tenants/models/feature_registry.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_profile_providers.dart';
import 'package:afyakit/core/home/models/staff_feature_def.dart';

import 'package:afyakit/core/home/widgets/admin_dashboard_screen.dart';
import 'package:afyakit/features/inventory/records/shared/records_dashboard_screen.dart';
import 'package:afyakit/features/inventory/reports/screens/stock_report_screen.dart';
import 'package:afyakit/features/inventory/views/screens/stock_screen.dart';
import 'package:afyakit/features/inventory/views/utils/inventory_mode_enum.dart';

import 'package:afyakit/features/clinical/patients/widgets/patient_profiles_screen.dart';
import 'package:afyakit/features/retail/catalog/widgets/catalog_screen.dart';
import 'package:afyakit/features/retail/contacts/widgets/contacts_screen.dart';
import 'package:afyakit/features/retail/invoices/widgets/invoices_list_screen.dart';
import 'package:afyakit/features/retail/payments/widgets/payments_list_screen.dart';
import 'package:afyakit/features/retail/quotes/widgets/quotes_list_screen.dart';
import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HomeScope { staff, member }

final class HomeRegistry {
  const HomeRegistry._();

  static List<StaffFeatureDef> featureTiles(
    WidgetRef ref,
    AuthUser user, {
    required HomeScope scope,
  }) {
    final profile = ref.watch(tenantProfileProvider).valueOrNull;

    return FeatureRegistry.features
        .map((f) => StaffFeatureDef(featureKey: f.key, destination: f.entry))
        .where((d) => _isVisibleForTenant(profile, d))
        .where((d) => _isAllowedForScope(ref, user, d, scope))
        .toList(growable: false);
  }

  static List<StaffFeatureDef> quickActions(
    WidgetRef ref,
    AuthUser user, {
    required HomeScope scope,
  }) {
    final profile = ref.watch(tenantProfileProvider).valueOrNull;
    final base = _actionsForScope(scope);

    return base
        .where((d) => _isVisibleForTenant(profile, d))
        .where((d) => _isAllowedForScope(ref, user, d, scope))
        .toList(growable: false);
  }

  static List<StaffFeatureDef> actionsFor(
    WidgetRef ref,
    AuthUser user,
    String featureKey, {
    required HomeScope scope,
  }) {
    final all = quickActions(ref, user, scope: scope);
    return all.where((a) => a.featureKey == featureKey).toList(growable: false);
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
      destination: _prescriptions,
      allowed: _requireStaff,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'Catalog',
      iconOverride: Icons.apps,
      destination: _catalog,
      allowedRef: _allowRetailForTenant,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'Contacts',
      iconOverride: Icons.people_alt,
      destination: _contacts,
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
      labelOverride: 'Invoices',
      iconOverride: Icons.receipt_outlined,
      destination: _invoices,
      allowedRef: _allowRetailForTenant,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'Payments',
      iconOverride: Icons.payments_outlined,
      destination: _payments,
      allowedRef: _allowRetailForTenant,
    ),
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
    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'Catalog',
      iconOverride: Icons.apps,
      destination: _catalog,
      allowedRef: _allowRetailForTenant,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.clinical,
      labelOverride: 'My Profiles',
      iconOverride: Icons.people_alt_outlined,
      destination: _myProfiles,
      allowedRef: _allowMemberUx,
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
      labelOverride: 'My Invoices',
      iconOverride: Icons.receipt_outlined,
      destination: _myInvoices,
      allowedRef: _allowRetailForTenant,
    ),
    StaffFeatureDef(
      featureKey: FeatureKeys.retail,
      labelOverride: 'My Payments',
      iconOverride: Icons.payments_outlined,
      destination: _myPayments,
      allowedRef: _allowRetailForTenant,
    ),
  ];

  static Widget _stockIn(BuildContext _) =>
      const StockScreen(mode: InventoryMode.stockIn);

  static Widget _stockOut(BuildContext _) =>
      const StockScreen(mode: InventoryMode.stockOut);

  static Widget _records(BuildContext _) => const RecordsDashboardScreen();

  static Widget _stockReport(BuildContext _) => const StockReportScreen();

  static Widget _admin(BuildContext _) => const AdminDashboardScreen();

  static Widget _contacts(BuildContext _) => const ContactsScreen();

  static Widget _catalog(BuildContext _) => const CatalogScreen();

  static Widget _quotes(BuildContext _) => const QuotesListScreen();

  static Widget _invoices(BuildContext _) => const InvoicesListScreen();

  static Widget _payments(BuildContext _) => const PaymentsListScreen();

  static Widget _patientProfiles(BuildContext _) =>
      const PatientProfilesScreen(allowExplicitContactLink: true);

  static Widget _prescriptions(BuildContext _) =>
      const _ComingSoonScreen(title: 'Prescriptions');

  static Widget _myProfiles(BuildContext _) => const PatientProfilesScreen();

  static Widget _myQuotes(BuildContext _) =>
      const QuotesListScreen(scope: RetailDocScope.mine);

  static Widget _myInvoices(BuildContext _) =>
      const InvoicesListScreen(scope: RetailDocScope.mine);

  static Widget _myPayments(BuildContext _) =>
      const PaymentsListScreen(scope: RetailDocScope.mine);

  static bool _requireStaff(AuthUser u) => u.isStaff;

  static bool _canAccessAdmin(AuthUser u) => u.canAccessAdminPanel;

  static bool _allowRetailForTenant(WidgetRef ref, AuthUser _) {
    final profile = ref.watch(tenantProfileProvider).valueOrNull;
    if (profile == null) return false;
    return profile.features.enabled(FeatureKeys.retail);
  }

  static bool _allowMemberUx(WidgetRef ref, AuthUser u) {
    if (u.isStaffResolved) return false;
    final acct = (u.accountNumber ?? '').trim();
    if (acct.isEmpty) return false;

    final profile = ref.watch(tenantProfileProvider).valueOrNull;
    if (profile == null) return false;

    final retail = profile.features.enabled(FeatureKeys.retail);
    final clinical = profile.features.enabled(FeatureKeys.clinical);
    return retail || clinical;
  }

  static bool _isAllowedForScope(
    WidgetRef ref,
    AuthUser user,
    StaffFeatureDef d,
    HomeScope scope,
  ) {
    if (scope == HomeScope.member) {
      final k = d.featureKey;
      if (k == FeatureKeys.inventory) return false;
      if (k == FeatureKeys.reporting) return false;
      if (k == FeatureKeys.hq) return false;
      if (k == FeatureKeys.clinical && d.destination != _myProfiles) {
        return false;
      }
    }

    final allowedFn = d.allowed;
    if (allowedFn != null && !allowedFn(user)) return false;

    final allowedRefFn = d.allowedRef;
    if (allowedRefFn != null && !allowedRefFn(ref, user)) return false;

    return true;
  }

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
}

class _ComingSoonScreen extends StatelessWidget {
  const _ComingSoonScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '$title screen coming next.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
