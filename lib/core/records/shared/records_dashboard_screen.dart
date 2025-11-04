import 'package:afyakit/core/records/deliveries/screens/delivery_records_screen.dart';
import 'package:afyakit/core/records/issues/screens/issue_records_screen.dart';
import 'package:afyakit/core/records/reorder/screens/reorder_records_screen.dart';
import 'package:afyakit/shared/widgets/base_screen.dart';
import 'package:afyakit/shared/widgets/screen_header/screen_header.dart';
import 'package:flutter/material.dart';

class RecordsDashboardScreen extends StatelessWidget {
  const RecordsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      scrollable: false,
      maxContentWidth: 800,
      header: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ScreenHeader('Records Dashboard'),
      ),
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
