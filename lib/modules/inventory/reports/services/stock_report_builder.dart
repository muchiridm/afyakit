import 'package:flutter/material.dart';
import 'package:afyakit/modules/inventory/batches/models/batch_record.dart';
import 'package:afyakit/modules/inventory/items/models/items/base_inventory_item.dart';
import 'package:afyakit/modules/inventory/reports/extensions/stock_report_x.dart';
import 'package:afyakit/modules/inventory/reports/extensions/stock_view_mode_enum.dart';
import 'package:afyakit/modules/inventory/reports/models/stock_report.dart';
import 'package:afyakit/shared/services/sku_batch_matcher.dart';

class StockReportBuilder {
  final List<BaseInventoryItem> items;
  final List<BatchRecord> batches;

  const StockReportBuilder({required this.items, required this.batches});

  List<StockReport> build(StockViewMode mode) {
    final matcher = SkuBatchMatcher.from(items: items, batches: batches);

    return switch (mode) {
      StockViewMode.skuOnly => _buildOnlySku(),
      StockViewMode.groupedPerStore => _buildPerStore(matcher),
      StockViewMode.groupedPerSku => _buildPerSku(matcher),
      StockViewMode.reorder => _buildReorder(matcher),
    };
  }

  // ─────────────────────────────────────────────────────────────
  // 📊 Report Builders
  // ─────────────────────────────────────────────────────────────

  List<StockReport> _buildOnlySku() {
    return items.map((item) => _buildReport(item: item)).toList();
  }

  List<StockReport> _buildPerStore(SkuBatchMatcher matcher) {
    final reports = <StockReport>[];

    for (final item in items) {
      final batchesByStore = matcher.getBatchesByStoreForItem(item);

      for (final MapEntry<String, List<BatchRecord>> entry
          in batchesByStore.entries) {
        final storeBatches = entry.value;
        if (storeBatches.isEmpty) continue;

        reports.add(
          _buildReport(
            item: item,
            storeId: entry.key,
            quantity: _sumQuantities(storeBatches),
            expiryDates: _sortUnique(
              storeBatches.map((b) => b.expiryDate).whereType<DateTime>(),
            ),
            stores: batchesByStore.keys.toList()..sort(),
          ),
        );
      }
    }

    return reports;
  }

  List<StockReport> _buildPerSku(SkuBatchMatcher matcher) {
    return items.map((item) {
      final batches = matcher.getBatchesForItem(item);
      if (batches.isEmpty) return _buildReport(item: item);

      return _buildReport(
        item: item,
        quantity: _sumQuantities(batches),
        expiryDates: _sortUnique(
          batches.map((b) => b.expiryDate).whereType<DateTime>(),
        ),
        stores: _sortUnique(
          batches.map((b) => b.storeId).where((id) => id.isNotEmpty),
        ),
      );
    }).toList();
  }

  List<StockReport> _buildReorder(SkuBatchMatcher matcher) {
    final mode = StockViewMode.reorder;

    final withStock = _buildPerSku(matcher);

    // Deduplicate by itemId
    final seenItemIds = withStock.map((r) => r.itemId).toSet();

    final withoutStock = items
        .map((item) {
          final fallback = _buildReport(item: item);
          return seenItemIds.contains(fallback.itemId) ? null : fallback;
        })
        .whereType<StockReport>()
        .toList();

    final combined = [...withStock, ...withoutStock];
    _logDuplicates(combined, label: 'reorder report', mode: mode);

    return combined;
  }

  // ─────────────────────────────────────────────────────────────
  // 🧰 Helpers
  // ─────────────────────────────────────────────────────────────

  StockReport _buildReport({
    required BaseInventoryItem item,
    String storeId = '',
    int quantity = 0,
    List<DateTime> expiryDates = const [],
    List<String> stores = const [],
  }) {
    return StockReport.fromItemWithQuantity(
      item,
      storeId: storeId,
      quantity: quantity,
      expiryDates: expiryDates,
      stores: stores,
    );
  }

  List<T> _sortUnique<T extends Comparable>(Iterable<T> values) {
    return values.toSet().toList()..sort();
  }

  int _sumQuantities(List<BatchRecord> batches) {
    return batches.fold(0, (sum, b) => sum + b.quantity);
  }

  void _logDuplicates(
    List<StockReport> reports, {
    required StockViewMode mode,
    String label = 'StockReports',
  }) {
    final seen = <String>{};
    final duplicates = <String>{};

    for (final r in reports) {
      final key = r.generateStableRowKey(mode);
      if (!seen.add(key)) duplicates.add(key);
    }

    debugPrint('📋 $label: ${reports.length} rows');
    if (duplicates.isEmpty) {
      debugPrint('✅ No duplicate row keys found.');
    } else {
      debugPrint('❌ ${duplicates.length} DUPLICATE row keys detected:');
      for (final d in duplicates) {
        debugPrint('🔁 $d');
      }
    }
  }
}
