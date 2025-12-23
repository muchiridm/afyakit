import 'package:afyakit/features/inventory/records/reorder/models/reorder_record.dart';
import 'package:afyakit/features/inventory/reports/providers/stock_report_services_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reorderRecordsProvider = FutureProvider<List<ReorderRecord>>((ref) async {
  final service = ref.watch(reorderServiceProvider);
  return service.fetchReorderRecords();
});
