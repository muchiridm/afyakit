import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/inventory/records/cart/inventory_cart_drawer.dart';
import 'package:afyakit/features/inventory/records/cart/inventory_cart_providers.dart';
import 'package:afyakit/features/inventory/records/deliveries/inventory_deliveries_screen.dart';
import 'package:afyakit/features/inventory/records/issues/inventory_issues_screen.dart';
import 'package:afyakit/features/inventory/records/reorders/inventory_reorders_screen.dart';
import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_page.dart';

/// Entry point for inventory transactions and procurement proposals.
/// Cart holds only staged issue selections and is never a stock ledger.
class RecordsDashboardScreen extends ConsumerWidget {
  const RecordsDashboardScreen({super.key, required this.appId});

  /// Retained as part of the calling navigation contract. The downstream
  /// modules resolve application identity through appIdProvider.
  final String appId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(inventoryCartProvider);
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return AppPage(
      scrollable: false,
      maxWidth: 800,
      header: AppHeader(
        title: 'Inventory Records',
        trailing: IconButton(
          tooltip: 'Review stock issue cart',
          onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
          icon: Badge(
            isLabelVisible: cart.totalQuantity > 0,
            label: Text('${cart.totalQuantity}'),
            child: const Icon(Icons.shopping_cart_outlined),
          ),
        ),
      ),
      body: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.transparent,
        endDrawer: const InventoryCartDrawer(),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _destination(
              context,
              icon: Icons.move_to_inbox_outlined,
              title: 'Deliveries',
              description: 'Receive stock and review finalized deliveries',
              screen: const InventoryDeliveriesScreen(),
            ),
            _destination(
              context,
              icon: Icons.outbox_outlined,
              title: 'Stock Issues',
              description:
                  'Transfer, dispense or dispose of stock; approve and receive',
              screen: const InventoryIssuesScreen(),
            ),
            _destination(
              context,
              icon: Icons.assignment_outlined,
              title: 'Reorders',
              description: 'Prepare and export procurement proposals',
              screen: const InventoryReordersScreen(),
            ),
            const SizedBox(height: 12),
            Text(
              'The cart stages an issue request. Stock balances change only when '
              'the backend executes delivery and issue transactions.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _destination(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Widget screen,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Icon(icon, size: 30),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => screen)),
      ),
    );
  }
}
