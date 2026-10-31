// lib/features/admin/widgets/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/tests/api_test_screen.dart';
import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/guards/permission_guard.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/auth/auth_user/widgets/screens/user_profile_manager_screen.dart';

import 'package:afyakit/core/capabilities/feature_keys.dart';
import 'package:afyakit/core/capabilities/widgets/feature_gate.dart';

import 'package:afyakit/features/backup/backup_screen.dart';

import 'package:afyakit/features/inventory/import/inventory_import_screen.dart';
import 'package:afyakit/features/inventory/locations/inventory_locations_screen.dart';
import 'package:afyakit/features/inventory/sources/inventory_sources_screen.dart';
import 'package:afyakit/features/inventory/preferences/item_preferences_screen.dart';

import 'package:afyakit/features/retail/meta/widgets/zoho_accounts_screen.dart';

import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_page.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(currentUserProvider);

    return meAsync.when(
      loading: () => const AppPage(
        scrollable: false,
        maxWidth: 800,
        header: AppHeader(title: 'Admin Dashboard'),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => AppPage(
        scrollable: false,
        maxWidth: 800,
        header: const AppHeader(title: 'Admin Dashboard'),
        body: Center(child: Text('Failed to load current user: $error')),
      ),
      data: (me) => PermissionGuard(
        user: me,
        allowed: (user) => user.canAccessAdminPanel,
        fallback: const AppPage(
          scrollable: false,
          maxWidth: 800,
          header: AppHeader(title: 'Admin Dashboard'),
          body: Center(child: Text('You do not have access to this page.')),
        ),
        child: const AppPage(
          scrollable: false,
          maxWidth: 800,
          header: AppHeader(title: 'Admin Dashboard'),
          body: Center(child: _AdminActions()),
        ),
      ),
    );
  }
}

class _AdminActions extends StatelessWidget {
  const _AdminActions();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      alignment: WrapAlignment.center,
      children: [
        _adminActionButton(
          context,
          icon: Icons.manage_accounts_outlined,
          label: 'Manage Users',
          destination: const UserProfileManagerScreen(),
        ),
        _adminActionButton(
          context,
          icon: Icons.settings_outlined,
          label: 'Item Preferences',
          destination: const ItemPreferencesScreen(),
        ),
        _adminActionButton(
          context,
          icon: Icons.location_on_outlined,
          label: 'Manage Locations',
          destination: const InventoryLocationsScreen(),
        ),
        _adminActionButton(
          context,
          icon: Icons.local_shipping_outlined,
          label: 'Manage Sources',
          destination: const InventorySourcesScreen(),
        ),
        _adminActionButton(
          context,
          icon: Icons.upload_file_outlined,
          label: 'Import Inventory',
          destination: const InventoryImportScreen(),
        ),
        _adminActionButton(
          context,
          icon: Icons.backup_outlined,
          label: 'Backup Data',
          destination: const BackupScreen(),
        ),
        _adminActionButton(
          context,
          icon: Icons.api_outlined,
          label: 'Test API',
          destination: const ApiTestScreen(),
        ),
        FeatureGate(
          featureKey: FeatureKeys.retail,
          fallback: const SizedBox.shrink(),
          child: _adminActionButton(
            context,
            icon: Icons.account_balance_outlined,
            label: 'Zoho Accounts',
            destination: const ZohoAccountsScreen(),
          ),
        ),
      ],
    );
  }

  Widget _adminActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget destination,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      onPressed: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => destination));
      },
    );
  }
}
