import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'inventory_source.dart';
import 'inventory_sources_service.dart';

final inventorySourcesServiceProvider =
    FutureProvider.autoDispose<InventorySourcesService>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  ref.watch(appIdProvider);
  final client = await ref.watch(afyakitClientFutureProvider.future);
  return InventorySourcesService(dio: client.dio, routes: AfyaKitRoutes(tenantId));
});

/// Active sources available for receiving stock.
final inventorySourcesProvider =
    FutureProvider.autoDispose<List<InventorySource>>((ref) async {
  final service = await ref.watch(inventorySourcesServiceProvider.future);
  return service.listAll();
});

/// Administrative list, including archived sources.
final allInventorySourcesProvider =
    FutureProvider.autoDispose<List<InventorySource>>((ref) async {
  final service = await ref.watch(inventorySourcesServiceProvider.future);
  return service.listAll(includeArchived: true);
});
