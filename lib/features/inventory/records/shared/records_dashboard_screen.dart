import 'package:flutter/material.dart';

import 'package:afyakit/features/inventory/records/deliveries/widgets/screens/delivery_records_screen.dart';
import 'package:afyakit/features/inventory/records/issues/widgets/screens/issue_records_screen.dart';
import 'package:afyakit/features/inventory/records/reorder/screens/reorder_records_screen.dart';

import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_page.dart';

class RecordsDashboardScreen extends StatelessWidget {
  const RecordsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      scrollable: false,
      maxWidth: 800,
      header: const AppHeader(title: 'Records Dashboard'),
      body: Center(
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          children: [
            _recordsButton(
              context,
              icon: Icons.local_shipping,
              label: 'Delivery Records',
              destination: const DeliveryRecordsScreen(),
            ),
            _recordsButton(
              context,
              icon: Icons.outbox,
              label: 'Stock Issues',
              destination: const IssueRecordsScreen(),
            ),
            _recordsButton(
              context,
              icon: Icons.shopping_cart_checkout,
              label: 'Reorders',
              destination: const ReorderRecordsScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordsButton(
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
