import 'package:afyakit/features/inventory/records/issues/services/stock_repo.dart';
import 'package:flutter/foundation.dart';
// FieldValue, Timestamp
import 'package:afyakit/shared/utils/firestore_instance.dart';

/// Transfer == atomic decrement of source batch + creation of a transit record.
/// Destination batch is created later by `receiveTransit(...)`.
class TransferService {
  final String tenantId;
  final StockRepo repo;

  TransferService(this.repo) : tenantId = repo.tenantId;

  /// Deterministic transit id → idempotent per entry.
  String _computeTransitId({
    required String sourceBatchId,
    required String itemId,
    required Map<String, dynamic> metadata,
  }) {
    final issueId = StockRepo.asString(metadata['issueId']);
    final entryId = StockRepo.asString(metadata['entryId']);
    final explicit = StockRepo.asString(metadata['transitId']);

    if (explicit.isNotEmpty) return explicit;
    if (issueId.isNotEmpty && entryId.isNotEmpty) {
      return 'transit_${issueId}_$entryId';
    }
    // Fallback: still deterministic enough to avoid dupes on retries.
    return 'transit_${sourceBatchId}_$itemId';
  }

  Future<void> transfer({
    required String fromStore,
    required String toStore,
    required String sourceBatchId,
    required String itemId,
    required int quantity,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (quantity <= 0) {
      throw StateError('❌ Quantity must be positive.');
    }

    debugPrint(
      '🚚 [transfer] tenant=$tenantId $fromStore → $toStore '
      'batch=$sourceBatchId item=$itemId qty=$quantity meta=$metadata',
    );

    final transitId = _computeTransitId(
      sourceBatchId: sourceBatchId,
      itemId: itemId,
      metadata: metadata,
    );

    final srcRef = repo.batchesCol(fromStore).doc(sourceBatchId);
    final transitRef = repo.transitDoc(transitId);

    // (Optional) nice label in transit.source if caller didn’t provide one
    final fromStoreName = await repo.readStoreName(fromStore) ?? fromStore;

    await db.runTransaction((tx) async {
      // Idempotency gate: transit exists → already issued for this entry
      final tSnap = await tx.get(transitRef);
      if (tSnap.exists) {
        debugPrint(
          '↪️ [transfer] transit exists → idempotent skip ($transitId)',
        );
        return;
      }

      // Load source batch
      final sSnap = await tx.get(srcRef);
      if (!sSnap.exists) {
        throw StateError('❌ Source batch not found: $sourceBatchId');
      }
      final s = sSnap.data()!;
      final srcItemId = StockRepo.asString(s['itemId']);
      final onHand = StockRepo.asInt(s['quantity']);

      if (srcItemId != itemId) {
        throw StateError(
          '❌ Item mismatch: batch.itemId=$srcItemId vs arg=$itemId',
        );
      }
      if (onHand < quantity) {
        throw StateError(
          '❌ Insufficient stock in $sourceBatchId (have $onHand, need $quantity)',
        );
      }

      // Optional metadata
      final baseItemType = StockRepo.asString(s['itemType']).isNotEmpty
          ? StockRepo.asString(s['itemType'])
          : (StockRepo.asString(metadata['itemType']).isNotEmpty
                ? StockRepo.asString(metadata['itemType'])
                : 'unknown');

      DateTime? baseExpiry;
      final rawExp = s['expiryDate'];
      if (rawExp is Timestamp) baseExpiry = rawExp.toDate();
      if (rawExp is String && rawExp.trim().isNotEmpty) {
        baseExpiry = DateTime.tryParse(rawExp.trim());
      }

      // Deduct source
      final next = onHand - quantity;
      if (next > 0) {
        tx.update(srcRef, {
          'quantity': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.delete(srcRef);
      }
      debugPrint('✂️ [transfer] decremented source to $next');

      // Build transit payload
      final sourceLabel = () {
        final s1 = StockRepo.asString(metadata['source']);
        if (s1.isNotEmpty) return s1;
        final s2 = StockRepo.asString(metadata['fromStoreName']);
        if (s2.isNotEmpty) return s2;
        return fromStoreName;
      }();

      final payload = StockRepo.sanitize({
        'tenantId': tenantId,
        'fromStore': fromStore,
        'toStore': toStore,
        'itemId': itemId,
        'itemType': baseItemType,
        'quantity': quantity,
        'batchId': sourceBatchId,
        'expiry': baseExpiry?.toIso8601String(),
        'source': sourceLabel,
        'sourceType': 'transfer',
        'sourceStoreId': fromStore,
        'issueId': StockRepo.asString(metadata['issueId']).ifEmptyOrNull(),
        'entryId': StockRepo.asString(metadata['entryId']).ifEmptyOrNull(),
        'received': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        ...metadata,
      });

      // Create transit
      tx.set(transitRef, payload);
      debugPrint('🛄 [transfer] transit created: $transitId');
    });

    // Not required for correctness, but keeps receive step smooth
    await repo.ensureStore(toStore);
  }
}

extension _StrX on String {
  String? ifEmptyOrNull() => trim().isEmpty ? null : this;
}
