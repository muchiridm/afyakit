// lib/features/records/issues/services/inventory_snapshot.dart
import 'package:afyakit/features/inventory/items/providers/item_stream_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/inventory/batches/providers/batch_records_stream_provider.dart';

import 'package:afyakit/features/inventory/batches/models/batch_record.dart';
import 'package:afyakit/features/inventory/items/models/items/medication_item.dart';
import 'package:afyakit/features/inventory/items/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/items/models/items/equipment_item.dart';

class InventorySnapshot {
  final List<BatchRecord> batches;
  final List<MedicationItem> meds;
  final List<ConsumableItem> cons;
  final List<EquipmentItem> equips;

  InventorySnapshot({
    required this.batches,
    required this.meds,
    required this.cons,
    required this.equips,
  });
}

InventorySnapshot readInventorySnapshot(Ref ref) {
  final tenantId = ref.read(tenantSlugProvider);

  List<T> read<T>(AsyncValue<List<T>> v) =>
      v.maybeWhen(data: (d) => d, orElse: () => const []);

  final batches = read(ref.read(batchRecordsStreamProvider(tenantId)));
  final meds = read(ref.read(medicationItemsStreamProvider(tenantId)));
  final cons = read(ref.read(consumableItemsStreamProvider(tenantId)));
  final equips = read(ref.read(equipmentItemsStreamProvider(tenantId)));

  return InventorySnapshot(
    batches: List<BatchRecord>.from(batches),
    meds: List<MedicationItem>.from(meds),
    cons: List<ConsumableItem>.from(cons),
    equips: List<EquipmentItem>.from(equips),
  );
}
