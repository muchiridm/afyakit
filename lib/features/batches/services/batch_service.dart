// lib/shared/providers/batch_service_provider.dart
import 'dart:convert';
import 'package:afyakit/features/inventory/models/item_type_enum.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final batchServiceProvider = Provider<BatchService>((ref) {
  final tokenProviderInstance = ref.read(tokenProvider);
  return BatchService(tokenProviderInstance);
});

class BatchService {
  final TokenProvider tokenProvider;
  BatchService(this.tokenProvider);

  Future<BatchRecord?> getBatchById(
    String tenantId,
    String storeId,
    String batchId,
  ) async {
    try {
      final doc = await db
          .collection('tenants')
          .doc(tenantId)
          .collection('stores')
          .doc(storeId)
          .collection('batches')
          .doc(batchId)
          .get();
      if (!doc.exists) return null;
      return BatchRecord.fromSnapshot(doc);
    } catch (e, stack) {
      debugPrint('❌ Failed to fetch batch $batchId from store $storeId: $e');
      debugPrint('🧱 Stack trace:\n$stack');
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // 🌐 API Write: Create / Update / Delete
  // ─────────────────────────────────────────────

  Future<BatchRecord> createBatch(
    String tenantId,
    String storeId,
    BatchRecord batch,
  ) async {
    final token = await tokenProvider.getToken();
    final uri = ApiRoutes(tenantId).createBatch(storeId);

    final body = batch.toJson()
      ..putIfAbsent('tenantId', () => tenantId); // ensure persisted

    debugPrint('🚀 Calling: $uri');
    debugPrint('📦 JSON: ${jsonEncode(body)}');

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'x-tenant-id': tenantId,
      },
      body: jsonEncode(body),
    );
    if (res.statusCode != 201) {
      throw Exception('❌ Failed to create batch: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return BatchRecord.fromJson(data['id'] as String, data);
  }

  Future<void> updateBatch(
    String tenantId,
    String storeId,
    BatchRecord batch,
  ) async {
    final token = await tokenProvider.getToken();
    final uri = ApiRoutes(tenantId).updateBatch(storeId, batch.id);

    final body = batch.toJson()..putIfAbsent('tenantId', () => tenantId);

    final res = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'x-tenant-id': tenantId,
      },
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('❌ Failed to update batch: ${res.body}');
    }
  }

  Future<void> deleteBatch(
    String tenantId,
    String storeId,
    String batchId,
  ) async {
    final token = await tokenProvider.getToken();
    final uri = ApiRoutes(tenantId).deleteBatch(storeId, batchId);

    final res = await http.delete(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'x-tenant-id': tenantId,
      },
    );
    if (res.statusCode != 200) {
      throw Exception('❌ Failed to delete batch: ${res.body}');
    }
  }

  // ─────────────────────────────────────────────
  // 🔎 Validation
  // ─────────────────────────────────────────────

  static Future<bool> hasLinkedBatches({
    required String tenantId,
    required String itemId,
    required ItemType itemType,
  }) async {
    if (tenantId.isEmpty || itemId.isEmpty) return false;
    try {
      final q = await db
          .collectionGroup('batches')
          .where('tenantId', isEqualTo: tenantId) // ← REQUIRED
          .where('itemId', isEqualTo: itemId)
          .where('itemType', isEqualTo: itemType.name)
          .limit(5)
          .get();

      final any = q.docs.isNotEmpty;
      debugPrint(
        any
            ? '📦 Linked batch exists for item=$itemId under $tenantId'
            : '✅ No linked batches for item=$itemId under $tenantId',
      );
      return any;
    } catch (e, st) {
      debugPrint('❌ hasLinkedBatches error: $e\n$st');
      return false;
    }
  }
}
