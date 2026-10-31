import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/app/providers/app_profile_providers.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_session_guard_provider.dart';
import 'inventory_delivery.dart';
import 'inventory_deliveries_service.dart';

final inventoryDeliveriesServiceProvider = FutureProvider.autoDispose<InventoryDeliveriesService>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final appId = ref.watch(appIdProvider);
  await ref.watch(tenantSessionGuardProvider.future);
  final client = await ref.watch(afyakitClientFutureProvider.future);
  return InventoryDeliveriesService(dio: client.dio, routes: AfyaKitRoutes(tenantId), appId: appId);
});
final inventoryDeliveriesProvider = FutureProvider.autoDispose<List<InventoryDelivery>>((ref) async {
  final service = await ref.watch(inventoryDeliveriesServiceProvider.future);
  return service.listAll();
});
final inventoryDeliveryProvider = FutureProvider.autoDispose.family<InventoryDelivery, String>((ref, id) async {
  final service = await ref.watch(inventoryDeliveriesServiceProvider.future);
  return service.get(id);
});
final inventoryOpenDeliverySessionProvider = FutureProvider.autoDispose<InventoryDeliverySession?>((ref) async {
  final service = await ref.watch(inventoryDeliveriesServiceProvider.future);
  return service.openSession();
});
