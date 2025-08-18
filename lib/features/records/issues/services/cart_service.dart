import 'package:collection/collection.dart';
import 'package:afyakit/features/records/issues/models/issue_entry.dart';
import 'package:afyakit/features/records/issues/models/view_models/cart_item_models.dart';
import 'package:afyakit/features/records/issues/widgets/issue_summary_preview.dart';
import 'package:afyakit/features/inventory/models/items/medication_item.dart';
import 'package:afyakit/features/inventory/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/models/items/equipment_item.dart';
import 'package:afyakit/features/batches/models/batch_record.dart';

import 'package:afyakit/shared/utils/format/format_date.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_item_type.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/shared/providers/stock/batch_records_stream_provider.dart';
import 'package:afyakit/features/inventory/providers/item_streams/medication_items_stream_provider.dart';
import 'package:afyakit/features/inventory/providers/item_streams/consumable_items_stream_provider.dart';
import 'package:afyakit/features/inventory/providers/item_streams/equipment_items_stream_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartService {
  final Ref ref;
  CartService(this.ref);

  List<CartDisplayItem> getDisplayItems(Map<String, Map<String, int>> cart) {
    final tenantId = ref.read(tenantIdProvider);

    // Use watch so providers that depend on this recompute reactively.
    final batches = ref
        .watch(batchRecordsStreamProvider(tenantId))
        .maybeWhen(data: (d) => d, orElse: () => <BatchRecord>[]);
    final meds = ref
        .watch(medicationItemsStreamProvider(tenantId))
        .maybeWhen(data: (d) => d, orElse: () => <MedicationItem>[]);
    final cons = ref
        .watch(consumableItemsStreamProvider(tenantId))
        .maybeWhen(data: (d) => d, orElse: () => <ConsumableItem>[]);
    final equips = ref
        .watch(equipmentItemsStreamProvider(tenantId))
        .maybeWhen(data: (d) => d, orElse: () => <EquipmentItem>[]);

    return cart.entries.map((entry) {
      final itemId = entry.key;
      final batchMap = entry.value;

      final med = meds.firstWhereOrNull((m) => m.id == itemId);
      final con = cons.firstWhereOrNull((c) => c.id == itemId);
      final eqp = equips.firstWhereOrNull((e) => e.id == itemId);

      final item = med ?? con ?? eqp;
      final itemType = resolveItemType(item);
      final label = med?.name ?? con?.name ?? eqp?.name ?? 'Unnamed Item';

      final subtitle = [
        if (med != null) ...[med.group, med.strength, med.formulation],
        if (med?.route?.isNotEmpty ?? false) med!.route!.join(', '),
        if (con != null) ...[con.size, con.unit],
        if (eqp != null) eqp.model,
      ].whereNotNull().join(' • ');

      final batchItems = batchMap.entries.map((e) {
        final batch = batches.firstWhereOrNull((b) => b.id == e.key);
        final label = batch != null
            ? '${batch.storeId} • ${formatDate(batch.expiryDate)}'
            : 'Unknown Store • No Expiry';

        return CartDisplayBatch(
          batchId: e.key,
          label: label,
          quantity: e.value,
          storeId: batch?.storeId ?? 'unknown',
        );
      }).toList();

      return CartDisplayItem(
        itemId: itemId,
        label: label,
        itemType: itemType,
        subtitle: subtitle,
        batches: batchItems,
      );
    }).toList();
  }

  Widget buildSummaryFromEntries(List<IssueEntry> entries) {
    if (entries.isEmpty) return const SizedBox();

    final tenantId = ref.read(tenantIdProvider);
    final batches = ref
        .watch(batchRecordsStreamProvider(tenantId))
        .maybeWhen(data: (d) => d, orElse: () => <BatchRecord>[]);

    return IssueSummaryPreview(entries: entries, batches: batches);
  }
}
