import 'package:afyakit/users/user_manager/screens/global_users_screen.dart';
import 'package:afyakit/users/user_manager/screens/super_admins_screen.dart';
import 'package:afyakit/users/user_manager/services/hq_api_client.dart';
import 'package:afyakit/users/user_manager/providers/hq_api_client_provider.dart';
import 'package:afyakit/tenants/screens/tenant_manager_screen.dart';
import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/shared/screens/screen_header.dart';
import 'package:afyakit/users/user_operations/widgets/auth_user_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HqDashboardScreen extends ConsumerWidget {
  const HqDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(hqApiClientProvider);

    return AuthUserGate(
      allow: (user) => user.isSuperAdmin, // 🔒 HQ-only access
      builder: (gateCtx) => BaseScreen(
        scrollable: false,
        maxContentWidth: 800,
        header: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: ScreenHeader('HQ Dashboard'),
        ),
        body: Center(child: _buildHqActions(gateCtx, api)),
      ),
    );
  }

  Widget _buildHqActions(BuildContext context, HqApiClient api) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      alignment: WrapAlignment.center,
      children: [
        _hqActionButton(
          context,
          icon: Icons.apartment,
          label: 'Tenant Manager',
          destination: const TenantManagerScreen(),
        ),

        _hqActionButton(
          context,
          icon: Icons.verified_user,
          label: 'Super Admins',
          destination: SuperAdminsScreen(api: api),
        ),

        // 👇 New: Global Users
        _hqActionButton(
          context,
          icon: Icons.people_alt,
          label: 'Global Users',
          destination: const GlobalUsersScreen(),
        ),
      ],
    );
  }

  Widget _hqActionButton(
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
