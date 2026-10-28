import 'package:afyakit/app/providers/app_profile_provider.dart';
import 'package:afyakit/features/inventory/items/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/items/models/items/equipment_item.dart';
import 'package:afyakit/features/inventory/items/models/items/medication_item.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final consumableItemsStreamProvider = StreamProvider.autoDispose
    .family<List<ConsumableItem>, String>((ref, tenantId) {
      final cleanTenantId = tenantId.trim().toLowerCase();
      final appId = ref.watch(appIdProvider).trim().toLowerCase();

      if (cleanTenantId.isEmpty || appId.isEmpty) {
        return Stream.value(const <ConsumableItem>[]);
      }

      return db
          .collection('tenants/$cleanTenantId/consumables')
          .where('app_id', isEqualTo: appId)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(ConsumableItem.fromDoc)
                .toList(growable: false),
          );
    });

final equipmentItemsStreamProvider = StreamProvider.autoDispose
    .family<List<EquipmentItem>, String>((ref, tenantId) {
      final cleanTenantId = tenantId.trim().toLowerCase();
      final appId = ref.watch(appIdProvider).trim().toLowerCase();

      if (cleanTenantId.isEmpty || appId.isEmpty) {
        return Stream.value(const <EquipmentItem>[]);
      }

      return db
          .collection('tenants/$cleanTenantId/equipments')
          .where('app_id', isEqualTo: appId)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(EquipmentItem.fromDoc)
                .toList(growable: false),
          );
    });

final medicationItemsStreamProvider = StreamProvider.autoDispose
    .family<List<MedicationItem>, String>((ref, tenantId) {
      final cleanTenantId = tenantId.trim().toLowerCase();
      final appId = ref.watch(appIdProvider).trim().toLowerCase();

      if (cleanTenantId.isEmpty || appId.isEmpty) {
        return Stream.value(const <MedicationItem>[]);
      }

      return db
          .collection('tenants/$cleanTenantId/medications')
          .where('app_id', isEqualTo: appId)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(MedicationItem.fromDoc)
                .toList(growable: false),
          );
    });
