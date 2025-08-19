import 'package:afyakit/features/backup/backup_screen.dart';
import 'package:afyakit/shared/api/api_test_screen.dart';
import 'package:afyakit/features/item_preferences/item_preferences_screen.dart';
import 'package:afyakit/features/inventory_locations/screens/inventory_locations_screen.dart';
import 'package:afyakit/users/user_manager/extensions/auth_user_x.dart';
import 'package:afyakit/users/screens/user_profile_manager_screen.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/shared/screens/screen_header.dart';
import 'package:afyakit/features/import/import_inventory_screen.dart';
import 'package:afyakit/users/widgets/auth_user_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);

    return AuthUserGate(
      allow: (user) => user.canAccessAdminPanel,
      builder: (_) => BaseScreen(
        scrollable: false,
        maxContentWidth: 800,
        header: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ScreenHeader('Admin Dashboard'),
        ),
        body: Center(child: _buildAdminActions(context, tenantId)),
      ),
    );
  }

  Widget _buildAdminActions(BuildContext context, String tenantId) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      alignment: WrapAlignment.center,
      children: [
        _adminActionButton(
          context,
          icon: Icons.manage_accounts,
          label: 'Manage Users',
          destination: UserProfileManagerScreen(),
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
