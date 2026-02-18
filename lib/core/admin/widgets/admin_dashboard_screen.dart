// lib/features/admin/widgets/admin_dashboard_screen.dart

import 'package:afyakit/hq/tenants/models/feature_keys.dart';
import 'package:afyakit/hq/tenants/widgets/feature_gate.dart';
import 'package:afyakit/features/retail/meta/widgets/zoho_accounts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/tests/api_test_screen.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_user_providers.dart';

import 'package:afyakit/features/backup/backup_screen.dart';
import 'package:afyakit/features/inventory/import/importer/import_inventory_screen.dart';
import 'package:afyakit/features/inventory/preferences/widgets/item_preferences_screen.dart';
import 'package:afyakit/features/inventory/locations/screens/inventory_locations_screen.dart';

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/widgets/screens/user_profile_manager_screen.dart';
import 'package:afyakit/core/auth/auth_user/guards/permission_guard.dart';

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
      error: (e, _) => AppPage(
        scrollable: false,
        maxWidth: 800,
        header: const AppHeader(title: 'Admin Dashboard'),
        body: Center(child: Text('❌ Failed to load current user: $e')),
      ),
      data: (me) {
        return PermissionGuard(
          user: me,
          allowed: (u) => u.canAccessAdminPanel,
          fallback: const AppPage(
            scrollable: false,
            maxWidth: 800,
            header: AppHeader(title: 'Admin Dashboard'),
            body: Center(
              child: Text('🚫 You do not have access to this page.'),
            ),
          ),
          child: const AppPage(
            scrollable: false,
            maxWidth: 800,
            header: AppHeader(title: 'Admin Dashboard'),
            body: Center(child: _AdminActions()),
          ),
        );
      },
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
          icon: Icons.manage_accounts,
          label: 'Manage Users',
          destination: const UserProfileManagerScreen(),
        ),
        _adminActionButton(
          context,
          icon: Icons.settings,
          label: 'Item Preferences',
          destination: const ItemPreferencesScreen(),
        ),
        _adminActionButton(
          context,
          icon: Icons.location_on,
          label: 'Manage Locations',
          destination: const LocationsScreen(),
        ),
        _adminActionButton(
          context,
          icon: Icons.upload_file,
          label: 'Import Inventory',
          destination: const ImportInventoryScreen(),
        ),
        _adminActionButton(
          context,
          icon: Icons.backup,
          label: 'Backup Data',
          destination: const BackupScreen(),
        ),
        _adminActionButton(
          context,
          icon: Icons.api,
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
        ).push(MaterialPageRoute(builder: (_) => destination));
      },
    );
  }
}
