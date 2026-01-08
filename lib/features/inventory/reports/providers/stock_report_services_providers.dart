// lib/features/inventory/reports/providers/stock_report_services_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

import 'package:afyakit/features/inventory/reports/providers/stock_report_provider.dart';
import 'package:afyakit/features/inventory/reports/services/sku_field_updater.dart';
import 'package:afyakit/features/inventory/reports/services/stock_report_loader.dart';
import 'package:afyakit/features/inventory/reports/services/stock_table_filter.dart';
import 'package:afyakit/features/inventory/records/reorder/services/reorder_service.dart';
import 'package:afyakit/features/inventory/reports/services/stock_report_exporter.dart';
import 'package:afyakit/features/inventory/reports/services/stock_report_service.dart';

/// ─────────────────────────────────────────────────────────────
/// StockReportService accessors
/// ─────────────────────────────────────────────────────────────

/// Canonical async service (use .when in UI/controllers if needed)
final stockReportServiceAsyncProvider =
    Provider<AsyncValue<StockReportService>>((ref) {
      return ref.watch(stockReportProvider);
    });

/// Safe resolved value (null while loading/error)
final stockReportServiceValueProvider = Provider<StockReportService?>((ref) {
  return ref.watch(stockReportProvider).valueOrNull;
});

/// ─────────────────────────────────────────────────────────────
/// StockReportLoader
/// ─────────────────────────────────────────────────────────────
///
/// Loader depends on StockReportService, which is async.
/// Therefore this MUST be async too.
///
/// ✅ Fixes the crash from calling requireValue during AsyncLoading.
final stockReportLoaderProvider = FutureProvider.autoDispose<StockReportLoader>(
  (ref) async {
    final reportService = await ref.watch(stockReportProvider.future);
    return StockReportLoader(reportService);
  },
);

/// Optional convenience: nullable loader value (null while loading/error)
final stockReportLoaderValueProvider = Provider<StockReportLoader?>((ref) {
  final async = ref.watch(stockReportLoaderProvider);
  return async.valueOrNull;
});

/// ─────────────────────────────────────────────────────────────
/// SkuFieldUpdater (depends on Ref)
/// ─────────────────────────────────────────────────────────────
final skuFieldSyncServiceProvider = Provider<SkuFieldUpdater>((ref) {
  return SkuFieldUpdater(ref);
});

/// ─────────────────────────────────────────────────────────────
/// Stateless filter service
/// ─────────────────────────────────────────────────────────────
final stockFilterServiceProvider = Provider<StockTableFilter>((ref) {
  return StockTableFilter();
});

/// ─────────────────────────────────────────────────────────────
/// ReorderService requires tenantId
/// ─────────────────────────────────────────────────────────────
final reorderServiceProvider = Provider<ReorderService>((ref) {
  final tenantId = ref.watch(tenantSlugProvider);
  return ReorderService(tenantId: tenantId);
});

/// ─────────────────────────────────────────────────────────────
/// Exporter (no args)
/// ─────────────────────────────────────────────────────────────
final stockReportExporterProvider = Provider<StockReportExporter>((ref) {
  return StockReportExporter();
});
