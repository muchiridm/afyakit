import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'inventory_item.dart';
import 'inventory_items_service.dart';

final inventoryItemsServiceProvider = FutureProvider<InventoryItemsService>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  ref.watch(
    appIdProvider,
  ); // Invalidates state when application context changes.
  final client = await ref.watch(afyakitClientFutureProvider.future);
  return InventoryItemsService(
    dio: client.dio,
    routes: AfyaKitRoutes(tenantId),
  );
});

final itemTypesProvider = FutureProvider<List<InventoryItemType>>((ref) async {
  final svc = await ref.watch(inventoryItemsServiceProvider.future);
  return svc.listTypes();
});

final itemsProvider = FutureProvider.family<InventoryPage, String>((
  ref,
  typeId,
) async {
  final svc = await ref.watch(inventoryItemsServiceProvider.future);
  return svc.list(typeId: typeId);
});

/// Administration includes inactive definitions; ordinary selectors do not.
final allItemTypesProvider = FutureProvider<List<InventoryItemType>>((
  ref,
) async {
  final svc = await ref.watch(inventoryItemsServiceProvider.future);
  return svc.listTypes(includeInactive: true);
});
