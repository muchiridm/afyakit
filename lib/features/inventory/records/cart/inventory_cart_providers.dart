import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'inventory_cart.dart';
import 'inventory_cart_controller.dart';

/// AutoDispose prevents carts from bleeding between application sessions.
final inventoryCartProvider = StateNotifierProvider.autoDispose<InventoryCartController, InventoryCart>(
  (ref) => InventoryCartController(),
);
