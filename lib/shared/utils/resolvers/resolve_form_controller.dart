import 'package:afyakit/features/inventory/controllers/forms/consumable_controller.dart';
import 'package:afyakit/features/inventory/controllers/forms/equipment_controller.dart';
import 'package:afyakit/features/inventory/controllers/forms/medication_controller.dart';
import 'package:afyakit/features/inventory/models/item_type_enum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

T resolveFormController<T>(WidgetRef ref, ItemType type) {
  return switch (type) {
    ItemType.medication => ref.read(medicationControllerProvider) as T,
    ItemType.consumable => ref.read(consumableControllerProvider) as T,
    ItemType.equipment => ref.read(equipmentControllerProvider) as T,
    ItemType.unknown => throw ArgumentError('Unknown item type.'),
  };
}
