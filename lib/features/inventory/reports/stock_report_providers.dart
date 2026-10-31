import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/inventory/items/inventory_items_providers.dart';
import 'package:afyakit/features/inventory/batches/inventory_batches_providers.dart';
import 'package:afyakit/features/inventory/locations/inventory_locations_providers.dart';
import 'stock_report.dart';
import 'stock_report_service.dart';

final stockReportProvider = FutureProvider.autoDispose<StockReport>((
  ref,
) async {
  final items = await ref.watch(inventoryItemsServiceProvider.future);
  final batches = await ref.watch(inventoryBatchesServiceProvider.future);
  final locations = await ref.watch(inventoryLocationsServiceProvider.future);
  return StockReportService(
    items: items,
    batches: batches,
    locations: locations,
  ).load();
});
