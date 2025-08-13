import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/utils/normalize/normalize_date.dart';
import 'package:afyakit/features/batches/models/batch_record.dart';
import '../services/batch_service.dart';
import '../services/batch_record_validator.dart';

// ─────────────────────────────────────────────
// 🧠 Tenant-scoped StateNotifier for batches
// ─────────────────────────────────────────────
final batchControllerProvider = StateNotifierProvider.autoDispose
    .family<BatchController, List<BatchRecord>, String>((ref, tenantId) {
      final service = ref.read(batchServiceProvider); // Injected 🔥
      return BatchController(ref, tenantId, service);
    });

class BatchController extends StateNotifier<List<BatchRecord>> {
  final Ref ref;
  final String tenantId;
  final BatchService _service;

  BatchController(this.ref, this.tenantId, this._service) : super([]) {
    final link = ref.keepAlive();
    final timer = Timer(const Duration(seconds: 30), link.close);
    ref.onDispose(timer.cancel);
  }

  // ─────────────────────────────────────────────
  // ➕ CREATE
  // ─────────────────────────────────────────────
  Future<void> createBatch(BatchRecord batch) async {
    final enriched = batch.copyWith(
      receivedDate: normalizeDate(batch.receivedDate),
      expiryDate: normalizeDate(batch.expiryDate),
    );

    final errors = batchRecordValidator(enriched.toRawMap());
    if (errors.isNotEmpty) {
      throw Exception('Invalid batch data:\n• ${errors.join('\n• ')}');
    }

    final newBatch = await _service.createBatch(
      tenantId,
      enriched.storeId,
      enriched,
    );

    state = [...state, newBatch];
  }

  // ─────────────────────────────────────────────
  // ✏️ UPDATE
  // ─────────────────────────────────────────────
  Future<void> updateBatch(BatchRecord input) async {
    final enriched = input.copyWith(
      receivedDate: normalizeDate(input.receivedDate),
      expiryDate: normalizeDate(input.expiryDate),
    );

    final errors = batchRecordValidator(enriched.toRawMap());
    if (errors.isNotEmpty) {
      throw Exception('Invalid batch update:\n• ${errors.join('\n• ')}');
    }

    await _service.updateBatch(tenantId, enriched.storeId, enriched);
    state = state.map((b) => b.id == enriched.id ? enriched : b).toList();
  }

  Future<void> updateBatchQuantity({
    required String batchId,
    required int quantity,
  }) async {
    final batch = state.firstWhere(
      (b) => b.id == batchId,
      orElse: () => throw Exception('Batch not found: $batchId'),
    );
    await updateBatch(batch.copyWith(quantity: quantity));
  }

  // ─────────────────────────────────────────────
  // ❌ DELETE
  // ─────────────────────────────────────────────
  Future<void> deleteBatch(BatchRecord batch) async {
    await _service.deleteBatch(tenantId, batch.storeId, batch.id);
    state = state.where((b) => b.id != batch.id).toList();
  }
}
