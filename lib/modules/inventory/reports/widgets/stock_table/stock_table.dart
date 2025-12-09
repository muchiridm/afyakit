import 'package:data_table_2/data_table_2.dart';
import 'package:afyakit/modules/inventory/locations/inventory_location.dart';
import 'package:afyakit/modules/inventory/reports/controllers/stock_report_controller.dart';
import 'package:afyakit/modules/inventory/reports/controllers/stock_report_engine.dart';
import 'package:afyakit/modules/inventory/reports/controllers/stock_report_state.dart';
import 'package:afyakit/modules/inventory/reports/extensions/stock_report_x.dart';
import 'package:afyakit/modules/inventory/reports/extensions/stock_view_mode_enum.dart';
import 'package:afyakit/modules/inventory/reports/models/stock_report.dart';
import 'package:afyakit/modules/inventory/reports/models/view_models/stock_table_schema.dart';
import 'package:afyakit/modules/inventory/reports/widgets/stock_table/build_columns_and_rows.dart';
import 'package:afyakit/modules/inventory/reports/providers/visible_reports_provider.dart'; // 👈 NEW
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const double kMinStockTableWidth = 1000.0;

class StockTable extends ConsumerWidget {
  const StockTable({
    super.key,
    required this.scrollController,
    required this.allStores,
  });

  final ScrollController scrollController;
  final List<InventoryLocation> allStores;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockReportEngineProvider); // reactive state
    final viewMode = state.viewMode;

    // ✅ Single source of truth for rows
    final List<StockReport> reports = ref.watch(visibleReportsProvider);

    // Columns schema for current tab/mode
    final schema = StockTableSchema.forItem(
      itemType: state.currentTabType,
      viewMode: viewMode,
    );

    // Sort (driven by engine’s sort stack)
    final (sortColumn, sortAscending) = state.sortStack.isNotEmpty
        ? state.sortStack.first
        : (StockSortColumn.name, true);

    final sortIndex = StockSortColumn.values
        .indexOf(sortColumn)
        .clamp(0, schema.length - 1);

    // Debug duplicates (stable keys)
    assert(() {
      _logDuplicateKeys(reports, viewMode);
      return true;
    }());

    if (reports.isEmpty) {
      return const Center(child: Text('No matching stock records.'));
    }
    if (schema.isEmpty) {
      return const Center(child: Text('No columns to display.'));
    }

    return DataTable2(
      sortColumnIndex: sortIndex,
      sortAscending: sortAscending,
      columnSpacing: 12,
      dataRowHeight: 60,
      headingRowHeight: 56,
      headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
      fixedTopRows: 1,
      minWidth: kMinStockTableWidth,
      horizontalScrollController: scrollController,
      columns: buildStockTableColumns(
        schema: schema,
        onSort: (index, ascending) {
          final controller = ref.read(stockReportControllerProvider);
          final column = StockSortColumn.values[index];
          controller.toggleSortColumn(column, ascending);
        },
        sortColumnIndex: sortIndex,
        sortAscending: sortAscending,
      ),
      rows: List.generate(
        reports.length,
        (i) => buildStockTableRow(
          report: reports[i],
          viewMode: viewMode,
          schema: schema,
          stores: allStores,
        ),
      ),
    );
  }

  void _logDuplicateKeys(List<StockReport> rows, StockViewMode mode) {
    final keyCounts = <String, int>{};
    for (final row in rows) {
      final key = row.generateStableRowKey(mode);
      keyCounts[key] = (keyCounts[key] ?? 0) + 1;
    }
    final duplicates = keyCounts.entries.where((e) => e.value > 1);
    if (duplicates.isEmpty) {
      debugPrint('✅ No duplicate row keys found. (${rows.length} rows)');
    } else {
      debugPrint('❌ DUPLICATE ROW KEYS FOUND (${duplicates.length}):');
      for (final dup in duplicates) {
        debugPrint('🔁 ${dup.key} → ${dup.value} times');
      }
    }
  }
}
