// lib/features/reports/providers/visible_reports_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/inventory/reports/controllers/stock_report_engine.dart';
import 'package:afyakit/features/inventory/reports/models/stock_report.dart';

/// Exactly what the table should show right now.
final visibleReportsProvider = Provider.autoDispose<List<StockReport>>((ref) {
  final s = ref.watch(stockReportEngineProvider);
  return s.currentFilteredReports;
});

/// Summary from the same list.
final visibleSummaryProvider =
    Provider.autoDispose<({int itemCount, int totalQty})>((ref) {
      final rows = ref.watch(visibleReportsProvider);
      final total = rows.fold<int>(0, (sum, r) => sum + (r.quantity));
      return (itemCount: rows.length, totalQty: total);
    });
