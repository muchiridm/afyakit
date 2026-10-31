import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_session_guard_provider.dart';
import 'inventory_batch.dart';
import 'inventory_batches_service.dart';

final inventoryBatchesServiceProvider =
    FutureProvider.autoDispose<InventoryBatchesService>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final appId = ref.watch(appIdProvider);
  await ref.watch(tenantSessionGuardProvider.future);
  final client = await ref.watch(afyakitClientFutureProvider.future);
  return InventoryBatchesService(dio: client.dio,
      routes: AfyaKitRoutes(tenantId), appId: appId);
});

/// Set storeId to null to list batches across all stores in the active app.
final inventoryBatchesProvider = FutureProvider.autoDispose
    .family<List<InventoryBatch>, String?>((ref, storeId) async {
  final service = await ref.watch(inventoryBatchesServiceProvider.future);
  return service.listAll(storeId: storeId);
});

final archivedInventoryBatchesProvider = FutureProvider.autoDispose
    .family<List<InventoryBatch>, String?>((ref, storeId) async {
  final service = await ref.watch(inventoryBatchesServiceProvider.future);
  return service.listAll(storeId: storeId, includeArchived: true);
});
