// lib/features/reports/providers/stock_report_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/inventory/services/inventory_repo_service.dart';
import 'package:afyakit/features/reports/services/stock_report_service.dart';
import 'package:afyakit/features/batches/services/batch_repo.dart';
import 'package:afyakit/features/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/features/tenants/providers/firestore_tenant_guard.dart';

final batchRepoProvider = Provider.autoDispose<BatchRepo>((_) => BatchRepo());

final stockReportProvider = FutureProvider.autoDispose<StockReportService>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  final inventoryRepo = ref.watch(inventoryRepoProvider);
  final batchRepo = ref.watch(batchRepoProvider);

  // 🔐 make sure the ID token’s tenant matches the selected tenant
  await ref.watch(firestoreTenantGuardProvider.future);

  // keepAlive to reduce thrash
  final link = ref.keepAlive();
  Timer? purge;
  ref.onCancel(() => purge = Timer(const Duration(seconds: 20), link.close));
  ref.onResume(() => purge?.cancel());

  try {
    final medications = await inventoryRepo.getMedications(tenantId);
    final consumables = await inventoryRepo.getConsumables(tenantId);
    final equipments = await inventoryRepo.getEquipments(tenantId);

    // collectionGroup('batches').where('tenantId','==',tenantId)
    final batches = await batchRepo.fetch(tenantId);

    debugPrint(
      '✅ [stockReportProvider] tenant=$tenantId '
      'meds=${medications.length} cons=${consumables.length} '
      'equip=${equipments.length} batches=${batches.length}',
    );

    return StockReportService(
      medications: medications,
      consumables: consumables,
      equipments: equipments,
      batches: batches,
    );
  } catch (e, st) {
    debugPrint('❌ [stockReportProvider] tenant=$tenantId error=$e\n$st');
    rethrow;
  }
});

final resolvedStockReportProvider = Provider<StockReportService>((ref) {
  final async = ref.watch(stockReportProvider);
  return async.requireValue;
});
