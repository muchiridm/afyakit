import 'package:afyakit/features/inventory/items/inventory_items_service.dart';
import 'package:afyakit/features/inventory/batches/inventory_batches_service.dart';
import 'package:afyakit/features/inventory/locations/inventory_locations_service.dart';
import 'stock_report.dart';

class StockReportService {
  const StockReportService({required this.items, required this.batches, required this.locations});
  final InventoryItemsService items;
  final InventoryBatchesService batches;
  final InventoryLocationsService locations;

  Future<StockReport> load() async {
    final allItems = <dynamic>[];
    var page = 1;
    while (true) {
      final result = await items.list(page: page, perPage: 100);
      allItems.addAll(result.items);
      if (!result.hasMore) break;
      if (page >= 1000) throw StateError('Inventory items pagination exceeded 1,000 pages');
      page++;
    }
    final values = await Future.wait<dynamic>([
      batches.listAll(),
      locations.listAll(),
    ]);
    return StockReport(
      items: allItems.cast(),
      batches: values[0],
      locations: values[1],
    );
  }
}
