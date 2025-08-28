import 'package:afyakit/core/records/issues/services/stock_repo.dart';
import 'package:flutter/foundation.dart';

import 'package:afyakit/shared/utils/firestore_instance.dart';

/// Encapsulates the two-phase transfer, with compensation & clear logs.
class TransferService {
  final String tenantId;
  final StockRepo repo;

  TransferService(this.repo) : tenantId = repo.tenantId;

  Future<void> transfer({
    required String fromStore,
    required String toStore,
    required String sourceBatchId,
    required String itemId,
    required int quantity,
    Map<String, dynamic> metadata = const {},
  }) async {
    debugPrint(
      '🚚 [transfer] tenant=$tenantId $fromStore → $toStore '
      'batch=$sourceBatchId item=$itemId qty=$quantity meta=$metadata',
    );

    final srcRef = repo.batchesCol(fromStore).doc(sourceBatchId);

    // Baseline (for compensation + payload)
    String? baseItemId;
    String? baseItemType;
    DateTime? baseExpiry;

    // Also the friendly name of the source store (for the "source" label).
    final fromStoreName = await repo.readStoreName(fromStore) ?? fromStore;

    // Read baseline once
    final base = await repo.readBatch(fromStore, sourceBatchId);
    if (base == null) {
      throw StateError('❌ Source batch not found: $sourceBatchId');
    }
    baseItemId = StockRepo.asString(base['itemId']);
    baseItemType = StockRepo.asString(base['itemType']);
    final rawExp = base['expiryDate'];
    if (rawExp is Timestamp) baseExpiry = rawExp.toDate();
    if (rawExp is String && rawExp.trim().isNotEmpty) {
      baseExpiry = DateTime.tryParse(rawExp.trim());
    }

    // Phase 1: decrement/delete
    await db.runTransaction((tx) async {
      final s = await tx.get(srcRef);
      if (!s.exists) {
        throw StateError('❌ Source batch not found: $sourceBatchId');
      }

      final m = s.data()!;
      final srcItemId = StockRepo.asString(m['itemId']);
      final srcQty = StockRepo.asInt(m['quantity']);

      if (srcItemId != itemId) {
        throw StateError(
          '❌ Item mismatch: batch.itemId=$srcItemId vs arg=$itemId',
        );
      }
      if (srcQty < quantity) {
        throw StateError(
          '❌ Insufficient stock in $sourceBatchId (have $srcQty, need $quantity)',
        );
      }

      final next = srcQty - quantity;
      if (next > 0) {
        tx.update(srcRef, {
          'quantity': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.delete(srcRef);
      }
      debugPrint('✂️ [transfer] decremented source to $next');
    });

    // Ensure destination store exists (outside tx)
    await repo.ensureStore(toStore);

    // Resolve a nice "source" label
    final resolvedSource = (() {
      final s1 = StockRepo.asString(metadata['source']);
      if (s1.isNotEmpty) return s1;
      final s2 = StockRepo.asString(metadata['fromStoreName']);
      if (s2.isNotEmpty) return s2;
      return fromStoreName;
    })();

    // Ensure *valid* item fields (hard stop if missing)
    final ensuredItemId = (baseItemId.isNotEmpty == true) ? baseItemId : itemId;
    final ensuredItemType = (baseItemType.isNotEmpty == true)
        ? baseItemType
        : StockRepo.asString(metadata['itemType']).isNotEmpty
        ? StockRepo.asString(metadata['itemType'])
        : 'unknown';

    if (ensuredItemId.trim().isEmpty) {
      // never write a broken document
      await repo.compensateSource(
        fromStore: fromStore,
        sourceBatchId: sourceBatchId,
        quantity: quantity,
        itemId: baseItemId,
        itemType: baseItemType,
        expiry: baseExpiry,
      );
      throw StateError(
        'internal: transfer missing itemId (src=$sourceBatchId)',
      );
    }

    // Phase 2: write destination batch
    final payload = StockRepo.sanitize({
      'tenantId': tenantId,
      'storeId': toStore,
      'itemId': ensuredItemId,
      'itemType': ensuredItemType,
      'quantity': quantity,
      'receivedDate': FieldValue.serverTimestamp(),
      'expiryDate': baseExpiry != null ? Timestamp.fromDate(baseExpiry) : null,
      'sourceBatchId': sourceBatchId,
      'source': resolvedSource,
      'sourceType': 'transfer',
      'sourceStoreId': fromStore,
      'deliveryId': null,
      'isEdited': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      ...metadata,
    });

    try {
      final destRef = await repo.createBatch(toStore, payload);
      debugPrint('✅ [transfer] dest created: ${destRef.id}');
      // quick verify
      try {
        final check = await destRef.get();
        debugPrint(
          check.exists
              ? '🔎 [transfer] verified dest exists: ${check.id}'
              : '🔎 [transfer] dest not found after create?!',
        );
      } catch (_) {}
    } catch (e, st) {
      debugPrint('💥 [transfer] dest set failed (${e.runtimeType}): $e\n$st');

      // Compensate the source since phase 1 succeeded
      try {
        await repo.compensateSource(
          fromStore: fromStore,
          sourceBatchId: sourceBatchId,
          quantity: quantity,
          itemId: baseItemId,
          itemType: baseItemType,
          expiry: baseExpiry,
        );
        debugPrint('↩️ [transfer] compensated source after dest failure');
      } catch (ce) {
        debugPrint('💥 [transfer] compensation failed: $ce');
      }
      rethrow;
    }
  }
}
