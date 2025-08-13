import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'package:afyakit/features/inventory/services/inventory_repo_service.dart';
import 'package:afyakit/features/reports/services/stock_report_service.dart';
import 'package:afyakit/features/batches/services/batch_repo.dart';
import 'package:afyakit/shared/providers/tenant_provider.dart';

final stockReportProvider = FutureProvider.autoDispose<StockReportService>((
  ref,
) async {
  final tenantId = ref.read(tenantIdProvider);
  final inventoryRepo = InventoryRepoService();
  final batchRepo = BatchRepo();

  final medications = await inventoryRepo.getMedications(tenantId);
  final consumables = await inventoryRepo.getConsumables(tenantId);
  final equipments = await inventoryRepo.getEquipments(tenantId);
  final batches = await batchRepo.fetch(tenantId);

  debugPrint(
    '✅ [stockReportProvider] Loaded: '
    'meds=${medications.length}, '
    'cons=${consumables.length}, '
    'equip=${equipments.length}, '
    'batches=${batches.length}',
  );

  return StockReportService(
    medications: medications,
    consumables: consumables,
    equipments: equipments,
    batches: batches,
  );
});

/// ✅ Exposes resolved StockReportService only after load
final resolvedStockReportProvider = Provider<StockReportService>((ref) {
  final async = ref.watch(stockReportProvider);
  return async
      .requireValue; // 🛑 throws if accessed before stockReportProvider is ready
});
