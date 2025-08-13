// lib/features/src/delivery_sessions/utils/resolve_item_name.dart

import 'package:collection/collection.dart';
import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/features/inventory/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/models/items/equipment_item.dart';
import 'package:afyakit/features/inventory/models/items/medication_item.dart';
import 'package:afyakit/features/inventory/models/item_type_enum.dart';

String resolveItemName(
  BatchRecord b,
  List<MedicationItem> meds,
  List<ConsumableItem> cons,
  List<EquipmentItem> equip,
) {
  return switch (b.itemType) {
    ItemType.medication =>
      meds.firstWhereOrNull((m) => m.id == b.itemId)?.name ??
          'Unnamed Medication',
    ItemType.consumable =>
      cons.firstWhereOrNull((c) => c.id == b.itemId)?.name ??
          'Unnamed Consumable',
    ItemType.equipment =>
      equip.firstWhereOrNull((e) => e.id == b.itemId)?.name ??
          'Unnamed Equipment',
    ItemType.unknown => 'Unknown Item',
  };
}
