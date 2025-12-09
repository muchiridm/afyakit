import 'package:afyakit/modules/inventory/reports/providers/stock_report_provider.dart';
import 'package:afyakit/modules/inventory/reports/services/sku_field_updater.dart';
import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/modules/inventory/reports/services/stock_report_loader.dart';
import 'package:afyakit/modules/inventory/reports/services/stock_table_filter.dart';
import 'package:afyakit/modules/inventory/records/reorder/services/reorder_service.dart';
import 'package:afyakit/modules/inventory/reports/services/stock_report_exporter.dart';

// ✅ StockReportLoader depends on Ref
final stockReportLoaderProvider = Provider<StockReportLoader>((ref) {
  final reportService = ref.watch(stockReportProvider).requireValue;
  return StockReportLoader(reportService);
});

// ✅ SkuFieldUpdater depends on Ref
final skuFieldSyncServiceProvider = Provider<SkuFieldUpdater>((ref) {
  return SkuFieldUpdater(ref);
});

// ✅ Stateless
final stockFilterServiceProvider = Provider<StockTableFilter>((ref) {
  return StockTableFilter();
});

// ✅ ReorderService requires tenantId
final reorderServiceProvider = Provider<ReorderService>((ref) {
  final tenantId = ref.watch(tenantSlugProvider);
  return ReorderService(tenantId: tenantId);
});

// ✅ Exporter needs Ref for reading inventory, batches, etc.
final stockReportExporterProvider = Provider<StockReportExporter>((ref) {
  return StockReportExporter(); // No args
});
