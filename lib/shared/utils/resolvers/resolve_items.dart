import 'package:afyakit/modules/inventory/items/controllers/forms/consumable_controller.dart';
import 'package:afyakit/modules/inventory/items/controllers/forms/equipment_controller.dart';
import 'package:afyakit/modules/inventory/items/controllers/forms/medication_controller.dart';
import 'package:afyakit/modules/inventory/items/extensions/item_type_x.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

List<T> resolveItems<T>(WidgetRef ref, ItemType type) {
  return switch (type) {
    ItemType.medication => ref.read(medicationControllerProvider).all.cast<T>(),
    ItemType.consumable => ref.read(consumableControllerProvider).all.cast<T>(),
    ItemType.equipment => ref.read(equipmentControllerProvider).all.cast<T>(),
    ItemType.unknown => throw ArgumentError(
      '❌ Cannot resolve items list for unknown item type.',
    ),
  };
}
