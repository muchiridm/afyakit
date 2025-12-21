import 'package:afyakit/core/auth_user/providers/current_user_providers.dart';
import 'package:afyakit/modules/inventory/records/shared/records_dashboard_screen.dart';
import 'package:afyakit/core/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/modules/inventory/views/screens/stock_screen.dart';
import 'package:afyakit/modules/inventory/views/utils/inventory_mode_enum.dart';
import 'package:afyakit/modules/inventory/reports/screens/reports_dashboard_screen.dart';
import 'package:afyakit/shared/widgets/screens/admin_dashboard_screen.dart';

class StaffHomeActions extends ConsumerWidget {
  const StaffHomeActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AsyncValue<AuthUser?> → AuthUser?
    final userAsync = ref.watch(currentUserProvider);
    final AuthUser? user = userAsync.valueOrNull;

    // DEBUG: see what the model actually has
    userAsync.whenData((u) {
      debugPrint('AUTH DEBUG → uid=${u?.uid}');
      debugPrint(
        'AUTH DEBUG → staffRoles=${u?.staffRoles.map((r) => r.wire).toList()}',
      );
      debugPrint(
        'AUTH DEBUG → isAdmin=${u?.isAdmin} '
        'canAccessAdminPanel=${u?.canAccessAdminPanel}',
      );
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        final buttonPairs = [
          ['hq'], // reserved / hidden row
          ['admin', 'reports'],
          ['stockIn', 'stockOut'],
          ['records'],
        ];

        final actionsMap = _buildActionsMap();
        final visiblePairs = buttonPairs
            .map((pair) {
              return pair
                  .map((key) => actionsMap[key])
                  .where((a) {
                    if (a == null) return false;
                    if (a.allowed == null) return true;
                    final u = user;
                    if (u == null) {
                      return false; // no user → no privileged actions
                    }
                    return a.allowed!(u);
                  })
                  .cast<PermissionedAction>()
                  .toList();
            })
            .where((pair) => pair.isNotEmpty)
            .toList();

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: visiblePairs.map((pair) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: pair
                      .map(
                        (action) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: _buildButton(context, action),
                        ),
                      )
                      .toList(),
                ),
              );
            }).toList(),
          );
        } else {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: visiblePairs.map((pair) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: pair.map((action) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _buildButton(context, action),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          );
        }
      },
    );
  }

  Map<String, PermissionedAction> _buildActionsMap() {
    return {
      'stockIn': PermissionedAction(
        icon: Icons.inventory,
        label: 'Stock In',
        destination: const StockScreen(mode: InventoryMode.stockIn),
      ),
      'stockOut': PermissionedAction(
        icon: Icons.exit_to_app,
        label: 'Stock Out',
        destination: const StockScreen(mode: InventoryMode.stockOut),
      ),
      'reports': PermissionedAction(
        icon: Icons.summarize,
        label: 'Reports',
        destination: const ReportsDashboardScreen(),
      ),
      'admin': PermissionedAction(
        icon: Icons.admin_panel_settings,
        label: 'Admin',
        destination: const AdminDashboardScreen(),
        allowed: (u) => u.canAccessAdminPanel,
      ),
      'records': PermissionedAction(
        icon: Icons.history,
        label: 'Records',
        destination: const RecordsDashboardScreen(),
      ),
      // 'hq' intentionally not mapped → row becomes a no-op
    };
  }

  Widget _buildButton(BuildContext context, PermissionedAction action) {
    return SizedBox(
      width: 140,
      height: 48,
      child: ElevatedButton.icon(
        icon: Icon(action.icon, size: 20),
        label: Text(action.label, style: const TextStyle(fontSize: 13)),
        style: _buttonStyle(context),
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => action.destination));
        },
      ),
    );
  }

  ButtonStyle _buttonStyle(BuildContext context) {
    return ElevatedButton.styleFrom(
      elevation: 2,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

class PermissionedAction {
  final IconData icon;
  final String label;
  final Widget destination;
  final bool Function(AuthUser user)? allowed;

  const PermissionedAction({
    required this.icon,
    required this.label,
    required this.destination,
    this.allowed,
  });
}
