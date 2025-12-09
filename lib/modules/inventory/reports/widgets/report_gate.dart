//library features/reports/widgets/report_gate.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/modules/inventory/reports/providers/stock_report_provider.dart';
import 'package:afyakit/modules/inventory/reports/services/stock_report_service.dart';

/// 🚪 Blocks rendering until [stockReportProvider] resolves.
/// Use this to wrap any screen that depends on [StockReportService].
class ReportGate extends ConsumerWidget {
  final Widget Function(BuildContext, StockReportService) builder;

  const ReportGate({super.key, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stockReportProvider);

    return async.when(
      data: (service) => builder(context, service),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 48),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '❌ Failed to load report service\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}
