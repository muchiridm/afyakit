// lib/shared/providers/batch_service.dart
import 'dart:convert';
import 'package:afyakit/api/api_routes.dart';
import 'package:afyakit/core/batches/models/batch_record.dart';
import 'package:afyakit/core/inventory/models/item_type_enum.dart';
import 'package:afyakit/core/auth_users/providers/auth_session/token_provider.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final batchServiceProvider = Provider<BatchService>((ref) {
  final tp = ref.read(tokenProvider);
  return BatchService(tp);
});

class BatchService {
  final TokenProvider tokenProvider;
  BatchService(this.tokenProvider);

  // ── Firestore read (used for lookups) ─────────────────────────
  Future<BatchRecord?> getBatchById(
    String tenantId,
    String storeId,
    String batchId,
  ) async {
    try {
      final doc = await db
          .collection('tenants/$tenantId/stores/$storeId/batches')
          .doc(batchId)
          .get();
      if (!doc.exists) return null;
      return BatchRecord.fromSnapshot(doc);
    } catch (e, st) {
      debugPrint('❌ getBatchById($batchId) failed: $e\n$st');
      return null;
    }
  }

  // ── Backend writes (create/update/delete) ─────────────────────
  Map<String, String> _headers(String token, String tenantId) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
    'x-tenant-id': tenantId,
  };

  Never _throwHttp(String op, http.Response res) {
    throw Exception('❌ $op failed [${res.statusCode}]: ${res.body}');
  }

  Future<BatchRecord> createBatch(
    String tenantId,
    String storeId,
    BatchRecord batch,
  ) async {
    final token = await tokenProvider.getToken();
    final uri = ApiRoutes(tenantId).createBatch(storeId);

    final body = batch.toJson()
      ..putIfAbsent('tenantId', () => tenantId)
      ..['delivery_id'] =
          batch.deliveryId; // we send it, but backend still drops it

    if (kDebugMode) {
      debugPrint('🚀 POST $uri');
      debugPrint('📦 ${jsonEncode(body)}');
    }

    final res = await http.post(
      uri,
      headers: _headers(token, tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode != 201) _throwHttp('createBatch', res);

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (kDebugMode) debugPrint('🔁 server payload: ${res.body}');

    final saved = BatchRecord.fromJson(data['id'] as String, data);

    // The API responds with "store" — prefer that, then fallback to passed-in.
    final resolvedStoreId =
        (data['storeId'] as String?) ??
        (data['store_id'] as String?) ??
        (data['store'] as String?) ??
        storeId;

    // 🔧 ensure Firestore doc has the fields our app/stream needs
    await _backfillCanonicalFields(
      tenantId: tenantId,
      storeId: resolvedStoreId,
      batchId: saved.id,
      deliveryId: batch.deliveryId,
      itemId: batch.itemId, // << ensure present
      itemTypeName: batch.itemType.name, // << ensure present
    );

    return saved;
  }

  Future<BatchRecord> updateBatch(
    String tenantId,
    String storeId,
    BatchRecord batch,
  ) async {
    final token = await tokenProvider.getToken();
    final uri = ApiRoutes(tenantId).updateBatch(storeId, batch.id);

    final body = batch.toJson()
      ..putIfAbsent('tenantId', () => tenantId)
      ..['delivery_id'] = batch.deliveryId;

    if (kDebugMode) {
      debugPrint('🛠 PUT $uri');
      debugPrint('📦 ${jsonEncode(body)}');
    }

    final res = await http.put(
      uri,
      headers: _headers(token, tenantId),
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) _throwHttp('updateBatch', res);

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (kDebugMode) debugPrint('🔁 server payload: ${res.body}');

    final saved = BatchRecord.fromJson(batch.id, data);

    final resolvedStoreId =
        (data['storeId'] as String?) ??
        (data['store_id'] as String?) ??
        (data['store'] as String?) ??
        storeId;

    await _backfillCanonicalFields(
      tenantId: tenantId,
      storeId: resolvedStoreId,
      batchId: saved.id,
      deliveryId: batch.deliveryId,
      itemId: batch.itemId, // << ensure present
      itemTypeName: batch.itemType.name, // << ensure present
    );

    return saved;
  }

  Future<void> deleteBatch(
    String tenantId,
    String storeId,
    String batchId,
  ) async {
    final token = await tokenProvider.getToken();
    final uri = ApiRoutes(tenantId).deleteBatch(storeId, batchId);

    final res = await http.delete(uri, headers: _headers(token, tenantId));
    if (res.statusCode != 200) _throwHttp('deleteBatch', res);
  }

  // ── Validation helper used elsewhere ──────────────────────────
  static Future<bool> hasLinkedBatches({
    required String tenantId,
    required String itemId,
    required ItemType itemType,
  }) async {
    if (tenantId.isEmpty || itemId.isEmpty) return false;
    try {
      final q = await db
          .collectionGroup('batches')
          .where('tenantId', isEqualTo: tenantId)
          .where('itemId', isEqualTo: itemId)
          .where('itemType', isEqualTo: itemType.name)
          .limit(5)
          .get();
      final any = q.docs.isNotEmpty;
      if (kDebugMode) {
        debugPrint(
          any
              ? '📦 Linked batch exists for item=$itemId under $tenantId'
              : '✅ No linked batches for item=$itemId under $tenantId',
        );
      }
      return any;
    } catch (e, st) {
      debugPrint('❌ hasLinkedBatches error: $e\n$st');
      return false;
    }
  }

  // lib/shared/providers/batch_service.dart
  // add this helper inside BatchService:
  Future<void> _backfillCanonicalFields({
    required String tenantId,
    required String storeId,
    required String batchId,
    required String? deliveryId,
    required String itemId,
    required String itemTypeName, // e.g. batch.itemType.name
  }) async {
    try {
      final ref = db
          .collection('tenants')
          .doc(tenantId)
          .collection('stores')
          .doc(storeId)
          .collection('batches')
          .doc(batchId);

      await db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final m = snap.data() ?? const <String, dynamic>{};
        String s(dynamic v) => (v ?? '').toString().trim();

        final patch = <String, dynamic>{};
        bool need = false;

        if (s(m['tenantId']).isEmpty) {
          patch['tenantId'] = tenantId;
          need = true;
        }
        if (s(m['storeId']).isEmpty) {
          patch['storeId'] = storeId;
          need = true;
        }
        if (s(m['itemId']).isEmpty && s(m['item_id']).isEmpty) {
          patch['itemId'] = itemId;
          need = true;
        }
        if (s(m['itemType']).isEmpty && s(m['item_type']).isEmpty) {
          patch['itemType'] = itemTypeName;
          need = true;
        }
        if (deliveryId != null &&
            deliveryId.isNotEmpty &&
            s(m['deliveryId']).isEmpty) {
          patch['deliveryId'] = deliveryId; // camel for app
          patch['delivery_id'] = deliveryId; // snake for legacy readers
          need = true;
        }

        if (need) tx.set(ref, patch, SetOptions(merge: true));
      });

      final after = await ref.get();
      debugPrint('🔎 backfilled ${after.reference.path} → ${after.data()}');
    } catch (e, st) {
      debugPrint('❌ backfill canonical fields failed: $e\n$st');
    }
  }
}
