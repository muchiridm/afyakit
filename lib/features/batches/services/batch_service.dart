import 'dart:convert';
import 'package:afyakit/features/inventory/models/item_type_enum.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// lib/shared/providers/batch_service_provider.dart (or nearby)
final batchServiceProvider = Provider<BatchService>((ref) {
  final tokenProviderInstance = ref.read(tokenProvider);
  return BatchService(tokenProviderInstance);
});

/// Service for managing batch-level stock records across stores
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
    final uri = ApiRoutes(tenantId).createBatchUri(storeId);

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(batch.toJson()),
    );

    if (res.statusCode != 201) {
      throw Exception('❌ Failed to create batch: ${res.body}');
    }

    final data = jsonDecode(res.body);

    debugPrint('🚀 Calling: ${uri.toString()}');
    debugPrint('📦 JSON: ${jsonEncode(batch.toJson())}');

    return BatchRecord.fromJson(data['id'], data);
  }

  Future<void> updateBatch(
    String tenantId,
    String storeId,
    BatchRecord batch,
  ) async {
    final token = await tokenProvider.getToken();
    final uri = ApiRoutes(tenantId).updateBatchUri(storeId, batch.id);

    final res = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(batch.toJson()),
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
    final uri = ApiRoutes(tenantId).deleteBatchUri(storeId, batchId);

    final res = await http.delete(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'x-tenant-id': tenantId, // 👈 Add this line
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
    if (tenantId.isEmpty || itemId.isEmpty) {
      debugPrint('⚠️ Skipped: tenantId or itemId is empty');
      return false;
    }

    try {
      final query = await db
          .collectionGroup('batches')
          .where('itemId', isEqualTo: itemId)
          .where('itemType', isEqualTo: itemType.name)
          .limit(5)
          .get();

      for (final doc in query.docs) {
        final segments = doc.reference.path.split('/');
        final tenantIndex = segments.indexOf('tenants');
        if (tenantIndex != -1 && segments[tenantIndex + 1] == tenantId) {
          debugPrint('📦 Linked batch found: ${doc.reference.path}');
          return true;
        }
      }

      debugPrint('✅ No linked batches for item $itemId under tenant $tenantId');
      return false;
    } catch (e) {
      debugPrint('❌ Error during batch linkage check: $e');
      return false;
    }
  }
}
