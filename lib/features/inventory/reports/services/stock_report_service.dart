import 'package:afyakit/features/inventory/items/models/items/base_inventory_item.dart';
import 'package:afyakit/features/inventory/items/models/items/medication_item.dart';
import 'package:afyakit/features/inventory/items/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/items/models/items/equipment_item.dart';
import 'package:afyakit/features/inventory/batches/models/batch_record.dart';
import 'package:afyakit/features/inventory/reports/models/stock_report.dart';
import 'package:afyakit/features/inventory/reports/extensions/stock_view_mode_enum.dart';
import 'package:afyakit/features/inventory/reports/services/stock_report_builder.dart';
import 'package:flutter/material.dart';

class StockReportService {
  final List<MedicationItem> medications;
  final List<ConsumableItem> consumables;
  final List<EquipmentItem> equipments;
  final List<BatchRecord> batches;

  final Map<StockViewMode, List<StockReport>> _reportCache = {};

  StockReportService({
    required this.medications,
    required this.consumables,
    required this.equipments,
    required this.batches,
  });

  List<BaseInventoryItem> get allItems => [
    ...medications,
    ...consumables,
    ...equipments,
  ];

  List<StockReport> buildReports({required StockViewMode mode}) {
    debugPrint('📊 Building report for mode: $mode');

    if (_reportCache.containsKey(mode)) {
      debugPrint('📁 Returning cached report for $mode');
      return _reportCache[mode]!;
    }

    final builder = StockReportBuilder(items: allItems, batches: batches);
    final reports = builder.build(mode);

    debugPrint('✅ Built ${reports.length} reports for $mode');

    _reportCache[mode] = reports;
    return reports;
  }
}
