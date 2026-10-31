import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_session_guard_provider.dart';
import 'inventory_location.dart';
import 'inventory_locations_service.dart';

final inventoryLocationsServiceProvider =
    FutureProvider.autoDispose<InventoryLocationsService>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final appId = ref.watch(appIdProvider);
  await ref.watch(tenantSessionGuardProvider.future);
  final client = await ref.watch(afyakitClientFutureProvider.future);
  return InventoryLocationsService(
    dio: client.dio,
    routes: AfyaKitRoutes(tenantId),
    appId: appId,
  );
});

/// Null type = all types. String slugs such as 'store' are not enums.
final inventoryLocationsProvider = FutureProvider.autoDispose
    .family<List<InventoryLocation>, String?>((ref, typeId) async {
  final service = await ref.watch(inventoryLocationsServiceProvider.future);
  return service.listAll(typeId: typeId);
});

final archivedInventoryLocationsProvider = FutureProvider.autoDispose
    .family<List<InventoryLocation>, String?>((ref, typeId) async {
  final service = await ref.watch(inventoryLocationsServiceProvider.future);
  return service.listAll(typeId: typeId, includeArchived: true);
});

final inventoryLocationTypesProvider = FutureProvider.autoDispose<List<InventoryLocationType>>((ref) async {
  final service = await ref.watch(inventoryLocationsServiceProvider.future);
  return service.listTypes();
});
