import 'package:afyakit/shared/providers/api_route_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:afyakit/features/inventory/services/inventory_service.dart';

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  final token = ref.read(tokenProvider);
  final routes = ref.read(apiRouteProvider);

  return InventoryService(routes, token);
});
