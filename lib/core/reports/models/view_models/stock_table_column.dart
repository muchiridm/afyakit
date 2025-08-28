import 'package:afyakit/core/reports/extensions/stock_table_column_id_enum.dart';

/// Represents a single column in a stock report table
class StockTableColumn {
  /// Unique ID used to identify and compare columns programmatically
  final StockTableColumnId id;

  /// Column label shown in the UI table header
  final String label;

  /// Fixed column width in pixels (default: 100)
  final double width;

  /// Whether this column supports sorting via table header
  final bool sortable;

  /// If sortable, this determines the order of sorting logic
  /// A lower index means higher priority in default sort fallback
  final int? sortIndex;

  /// Creates a new column definition
  const StockTableColumn({
    required this.id,
    required this.label,
    this.width = 100,
    this.sortable = false,
    this.sortIndex,
  });
}
