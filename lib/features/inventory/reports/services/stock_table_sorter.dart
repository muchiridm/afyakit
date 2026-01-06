import 'package:afyakit/features/inventory/reports/controllers/stock_report_state.dart';
import 'package:afyakit/features/inventory/reports/models/stock_report.dart';

class StockTableSorter {
  static List<StockReport> sort({
    required List<StockReport> input,
    required List<(StockSortColumn, bool)> sortStack,
  }) {
    if (sortStack.isEmpty) return input;

    final sorted = [...input];
    sorted.sort((a, b) {
      for (final (column, ascending) in sortStack) {
        final result = switch (column) {
          StockSortColumn.name => _compareStrings(a.name, b.name, ascending),
          StockSortColumn.group => _compareStrings(a.group, b.group, ascending),
        };

        if (result != 0) return result;
      }
      return 0;
    });
    return sorted;
  }

  static int _compareStrings(String? a, String? b, bool ascending) {
    final normA = (a ?? '').toLowerCase().trim();
    final normB = (b ?? '').toLowerCase().trim();
    return ascending ? normA.compareTo(normB) : normB.compareTo(normA);
  }
}
