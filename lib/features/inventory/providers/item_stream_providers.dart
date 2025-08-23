import 'package:afyakit/features/inventory/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/models/items/equipment_item.dart';
import 'package:afyakit/features/inventory/models/items/medication_item.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final consumableItemsStreamProvider = StreamProvider.autoDispose
    .family<List<ConsumableItem>, String>((ref, tenantId) {
      final query = db.collection('tenants/$tenantId/consumables');

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => ConsumableItem.fromDoc(doc)).toList();
      });
    });

final equipmentItemsStreamProvider = StreamProvider.autoDispose
    .family<List<EquipmentItem>, String>((ref, tenantId) {
      final query = db.collection('tenants/$tenantId/equipments');

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => EquipmentItem.fromDoc(doc)).toList();
      });
    });

final medicationItemsStreamProvider = StreamProvider.autoDispose
    .family<List<MedicationItem>, String>((ref, tenantId) {
      final query = db.collection('tenants/$tenantId/medications');

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => MedicationItem.fromDoc(doc)).toList();
      });
    });
