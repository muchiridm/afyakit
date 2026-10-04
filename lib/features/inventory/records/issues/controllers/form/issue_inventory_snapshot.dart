// lib/features/inventory/records/issues/controllers/form/issue_inventory_snapshot.dart

import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

import 'package:afyakit/features/inventory/batches/models/batch_record.dart';
import 'package:afyakit/features/inventory/batches/providers/batch_records_stream_provider.dart';

import 'package:afyakit/features/inventory/items/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/items/models/items/equipment_item.dart';
import 'package:afyakit/features/inventory/items/models/items/medication_item.dart';
import 'package:afyakit/features/inventory/items/providers/item_stream_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class InventorySnapshot {
  final List<BatchRecord> batches;
  final List<MedicationItem> meds;
  final List<ConsumableItem> cons;
  final List<EquipmentItem> equips;

  const InventorySnapshot({
    required this.batches,
    required this.meds,
    required this.cons,
    required this.equips,
  });
}

InventorySnapshot readInventorySnapshot(Ref ref) {
  final tenantId = ref.read(tenantIdProvider);

  final batches = _requireData(
    ref.read(batchRecordsStreamProvider(tenantId)),
    'batches',
  );

  final meds = _requireData(
    ref.read(medicationItemsStreamProvider(tenantId)),
    'medications',
  );

  final cons = _requireData(
    ref.read(consumableItemsStreamProvider(tenantId)),
    'consumables',
  );

  final equips = _requireData(
    ref.read(equipmentItemsStreamProvider(tenantId)),
    'equipment',
  );

  return InventorySnapshot(
    batches: List<BatchRecord>.from(batches),
    meds: List<MedicationItem>.from(meds),
    cons: List<ConsumableItem>.from(cons),
    equips: List<EquipmentItem>.from(equips),
  );
}

List<T> _requireData<T>(AsyncValue<List<T>> value, String label) {
  return value.when(
    data: (data) => data,
    loading: () => throw StateError('Inventory $label are still loading.'),
    error: (error, _) =>
        throw StateError('Failed to load inventory $label: $error'),
  );
}
