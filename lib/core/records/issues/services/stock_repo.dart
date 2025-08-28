import 'package:flutter/foundation.dart';

import 'package:afyakit/shared/utils/firestore_instance.dart';

/// Very small Firestore adapter: paths + a few primitives.
/// Keep business logic out of here.
class StockRepo {
  final String tenantId;
  StockRepo(this.tenantId);

  // ── paths ─────────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> _tenantCol() =>
      db.collection('tenants');

  DocumentReference<Map<String, dynamic>> _tenantDoc() =>
      _tenantCol().doc(tenantId);

  CollectionReference<Map<String, dynamic>> storesCol() =>
      _tenantDoc().collection('stores');

  DocumentReference<Map<String, dynamic>> storeDoc(String storeId) =>
      storesCol().doc(storeId);

  CollectionReference<Map<String, dynamic>> batchesCol(String storeId) =>
      storeDoc(storeId).collection('batches');

  CollectionReference<Map<String, dynamic>> transitCol() =>
      _tenantDoc().collection('batch_transit');

  DocumentReference<Map<String, dynamic>> transitDoc(String id) =>
      transitCol().doc(id);

  CollectionReference<Map<String, dynamic>> issuesCol() =>
      _tenantDoc().collection('issue_records');

  CollectionReference<Map<String, dynamic>> dispensationsCol() =>
      _tenantDoc().collection('batch_dispensations');

  CollectionReference<Map<String, dynamic>> disposalsCol() =>
      _tenantDoc().collection('batch_disposals');

  // ── primitives ────────────────────────────────────────────────
  Future<Map<String, dynamic>?> readBatch(
    String storeId,
    String batchId,
  ) async {
    final snap = await batchesCol(storeId).doc(batchId).get();
    return snap.data();
  }

  Future<String?> readStoreName(String storeId) async {
    try {
      final snap = await storeDoc(storeId).get();
      return (snap.data()?['name'] as String?)?.trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> ensureStore(String storeId) async {
    final ref = storeDoc(storeId);
    final snap = await ref.get();
    if (!snap.exists) {
      debugPrint('🏗️ [repo] creating store $storeId');
      await ref.set({
        'storeId': storeId,
        'name': storeId.replaceAll('_', ' ').toUpperCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> decrementOrDelete({
    required String storeId,
    required String batchId,
    required int amount,
  }) async {
    final ref = batchesCol(storeId).doc(batchId);
    await db.runTransaction((tx) async {
      final s = await tx.get(ref);
      if (!s.exists) throw StateError('❌ Batch not found: $batchId');
      final m = s.data()!;
      final cur = (m['quantity'] is num)
          ? (m['quantity'] as num).toInt()
          : int.tryParse('${m['quantity']}') ?? 0;
      if (cur < amount) {
        throw StateError('❌ Insufficient stock in $batchId');
      }
      final next = cur - amount;
      if (next > 0) {
        tx.update(ref, {
          'quantity': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.delete(ref);
      }
    });
  }

  Future<DocumentReference<Map<String, dynamic>>> createBatch(
    String storeId,
    Map<String, dynamic> payload,
  ) async {
    final ref = batchesCol(storeId).doc();
    await ref.set(payload);
    return ref;
  }

  Future<void> setBatch(
    String storeId,
    String batchId,
    Map<String, dynamic> payload,
  ) async {
    await batchesCol(storeId).doc(batchId).set(payload);
  }

  Future<void> compensateSource({
    required String fromStore,
    required String sourceBatchId,
    required int quantity,
    required String? itemId,
    required String? itemType,
    required DateTime? expiry,
  }) async {
    final ref = batchesCol(fromStore).doc(sourceBatchId);
    await db.runTransaction((tx) async {
      final s = await tx.get(ref);
      if (s.exists) {
        final m = s.data()!;
        final cur = (m['quantity'] is num)
            ? (m['quantity'] as num).toInt()
            : int.tryParse('${m['quantity']}') ?? 0;
        tx.update(ref, {
          'quantity': cur + quantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(ref, {
          'tenantId': tenantId,
          'storeId': fromStore,
          'itemId': (itemId ?? 'unknown').trim(),
          'itemType': (itemType ?? 'unknown').trim(),
          'quantity': quantity,
          'receivedDate': FieldValue.serverTimestamp(),
          'expiryDate': expiry != null ? Timestamp.fromDate(expiry) : null,
          'source': 'compensate',
          'deliveryId': null,
          'isEdited': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ── utils ─────────────────────────────────────────────────────
  static Map<String, dynamic> sanitize(Map<String, dynamic> m) {
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      if (v == null ||
          v is num ||
          v is String ||
          v is bool ||
          v is FieldValue ||
          v is Timestamp) {
        out[k] = v;
      } else if (v is DateTime) {
        out[k] = Timestamp.fromDate(v);
      } else {
        out[k] = v.toString();
      }
    });
    return out;
  }

  static String asString(dynamic v) => (v ?? '').toString().trim();
  static int asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(asString(v)) ?? 0;
  }
}
