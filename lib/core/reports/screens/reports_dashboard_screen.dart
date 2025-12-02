// lib/core/reports/screens/reports_dashboard_screen.dart

import 'package:afyakit/core/reports/screens/stock_report_screen.dart';
import 'package:afyakit/core/reports/widgets/report_gate.dart';
import 'package:afyakit/shared/widgets/base_screen.dart';
import 'package:afyakit/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReportsDashboardScreen extends ConsumerWidget {
  const ReportsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseScreen(
      scrollable: false,
      maxContentWidth: 800,
      header: const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: ScreenHeader('Reports Dashboard'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [_buildReportActions(context)],
          ),
        ),
      ),
    );
  }

  Widget _buildReportActions(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _reportActionButton(
          context,
          icon: Icons.inventory_2_rounded,
          label: 'Stock Report',
          destination: const _StockReportScreenWithGate(),
        ),
        // more buttons here
      ],
    );
  }

  Widget _reportActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    Widget? destination,
    VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed:
          onPressed ??
          () {
            if (destination != null) {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => destination));
            }
          },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 0,
        backgroundColor: Colors.deepPurple.shade50,
        foregroundColor: Colors.deepPurple,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center, // ✨ Key to fix alignment
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 1), // fine-tune if needed
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StockReportScreenWithGate extends StatelessWidget {
  const _StockReportScreenWithGate();

  @override
  Widget build(BuildContext context) {
    return ReportGate(builder: (_, __) => const StockReportScreen());
  }
}
