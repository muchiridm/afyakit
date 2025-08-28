import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import 'package:afyakit/core/inventory/models/items/base_inventory_item.dart';

import 'package:afyakit/core/inventory/models/item_type_enum.dart';
import 'package:afyakit/core/inventory/controllers/forms/medication_controller.dart';
import 'package:afyakit/core/inventory/controllers/forms/consumable_controller.dart';
import 'package:afyakit/core/inventory/controllers/forms/equipment_controller.dart';

T? findItemById<T extends BaseInventoryItem>(
  Ref ref,
  String itemId,
  ItemType type,
) {
  switch (type) {
    case ItemType.medication:
      return ref
          .read(medicationControllerProvider)
          .all
          .cast<T>()
          .firstWhereOrNull((i) => i.id == itemId);
    case ItemType.consumable:
      return ref
          .read(consumableControllerProvider)
          .all
          .cast<T>()
          .firstWhereOrNull((i) => i.id == itemId);
    case ItemType.equipment:
      return ref
          .read(equipmentControllerProvider)
          .all
          .cast<T>()
          .firstWhereOrNull((i) => i.id == itemId);
    case ItemType.unknown:
      debugPrint('⚠️ Attempted to lookup item with unknown type.');
      return null;
  }
}
