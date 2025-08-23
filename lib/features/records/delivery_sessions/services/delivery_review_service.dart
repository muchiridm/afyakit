// delivery_review_service.dart

import 'package:afyakit/features/inventory/providers/item_stream_providers.dart';
import 'package:afyakit/features/records/delivery_sessions/controllers/delivery_session_state.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_item_name.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/records/delivery_sessions/models/delivery_record.dart';
import 'package:afyakit/features/records/delivery_sessions/models/view_models/delivery_review_summary.dart';
import 'package:afyakit/features/batches/providers/batch_records_stream_provider.dart';

Future<DeliveryReviewSummary?> getDeliveryReviewSummary({
  required WidgetRef ref,
  required DeliverySessionState state,
  required String tenantId,
}) async {
  if (!state.isActive || state.deliveryId == null) return null;

  final batches = await ref.read(batchRecordsStreamProvider(tenantId).future);
  final deliveryBatches = batches
      .where((b) => b.deliveryId == state.deliveryId)
      .toList();
  if (deliveryBatches.isEmpty) return null;

  final meds = await ref.read(medicationItemsStreamProvider(tenantId).future);
  final cons = await ref.read(consumableItemsStreamProvider(tenantId).future);
  final equip = await ref.read(equipmentItemsStreamProvider(tenantId).future);

  final sources = deliveryBatches
      .map((b) => b.source?.trim())
      .where((s) => s?.isNotEmpty ?? false)
      .cast<String>()
      .toSet()
      .toList();

  final summary = DeliveryRecord.fromBatches(
    deliveryBatches,
    state.deliveryId!,
    enteredByName: state.enteredByName ?? 'unknown',
    enteredByEmail: state.enteredByEmail ?? 'unknown',
    sources: sources,
  );

  final items = deliveryBatches.map((b) {
    final name = resolveItemName(b, meds, cons, equip);
    return DeliveryReviewItem(
      name: name,
      quantity: b.quantity,
      store: b.storeId,
      type: b.itemType.name,
    );
  }).toList();

  return DeliveryReviewSummary(summary: summary, items: items);
}
