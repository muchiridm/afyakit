// lib/features/reports/extensions/stock_report_x.dart

import 'package:afyakit/core/reports/extensions/stock_view_mode_enum.dart';
import 'package:afyakit/core/reports/models/stock_report.dart';

extension StockReportX on StockReport {
  /// True if this row has any meaningful batch info
  bool get hasBatchInfo =>
      storeId.isNotEmpty || (expiryDates?.isNotEmpty ?? false) || quantity > 0;

  bool get isFallback => !hasBatchInfo;
  bool get hasQuantity => quantity > 0;
  bool get hasExpiry => expiryDates?.isNotEmpty ?? false;

  /// Stable key per row, guaranteed to be unique within a StockViewMode
  String generateStableRowKey(StockViewMode mode) {
    final batchMarker = hasBatchInfo ? 'batch' : 'fallback';
    final parts = <String>[itemType.name, itemId, mode.name, batchMarker];

    switch (mode) {
      case StockViewMode.skuOnly:
      case StockViewMode.groupedPerSku:
      case StockViewMode.reorder: // 👈 all 3 include storeId
        parts.addAll([
          storeId,
          proposedOrder?.toString() ?? '',
          reorderLevel?.toString() ?? '',
        ]);
        break;

      case StockViewMode.groupedPerStore:
        parts.addAll([
          storeId,
          expiryDates?.isNotEmpty == true
              ? expiryDates!.first.toIso8601String()
              : '',
        ]);
        break;
    }

    return parts.where((p) => p.isNotEmpty).join('|');
  }
}
