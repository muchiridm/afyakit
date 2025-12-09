// lib/features/batches/controllers/batch_engine.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/modules/inventory/batches/controllers/batch_like.dart';
import 'package:afyakit/modules/inventory/batches/models/batch_record.dart';
import 'package:afyakit/modules/inventory/batches/services/batch_service.dart';
import 'package:afyakit/modules/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/shared/utils/normalize/normalize_date.dart';
import 'package:afyakit/modules/inventory/records/deliveries/controllers/delivery_session_engine.dart';
import '../services/batch_record_validator.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';

final batchEngineProvider = StateNotifierProvider.autoDispose
    .family<BatchEngine, List<BatchRecord>, String>((ref, tenantId) {
      final service = ref.read(batchServiceProvider);
      return BatchEngine(ref, tenantId, service);
    });

class BatchEngine extends StateNotifier<List<BatchRecord>> {
  final Ref ref;
  final String tenantId;
  final BatchService _service;

  BatchEngine(this.ref, this.tenantId, this._service) : super(const []) {
    final link = ref.keepAlive();
    final timer = Timer(const Duration(seconds: 30), link.close);
    ref.onDispose(timer.cancel);
  }

  /// Create or update a batch. Guarantees an active delivery session first.
  Future<BatchRecord> save({
    required String itemId,
    required ItemType itemType,
    required BatchLike form,
    BatchRecord? existing,
    required String enteredByUid,
    required String enteredByName,
    required String enteredByEmail,
  }) async {
    _validateFormOrThrow(form, isEditing: existing != null);

    final store = form.storeId!.trim();
    final source = form.source!.trim();

    // 1) ensure an active delivery session
    final deliveryId = await _ensureDeliverySession(
      storeId: store,
      source: source,
      enteredByName: enteredByName,
      enteredByEmail: enteredByEmail,
    );

    // 2) build payload
    final payload = _buildRecord(
      itemId: itemId,
      itemType: itemType,
      form: form,
      deliveryId: deliveryId,
      enteredByUid: enteredByUid,
      enteredByName: enteredByName,
      enteredByEmail: enteredByEmail,
      existing: existing,
    );

    // 3) persist via API
    final saved = existing == null
        ? await _service.createBatch(tenantId, payload.storeId, payload)
        : await _service.updateBatch(tenantId, payload.storeId, payload);

    // 4) force-link the Firestore batch doc to this delivery (for banner/review)
    await _linkBatchToDeliveryInFirestore(
      storeId: payload.storeId,
      batchId: saved.id,
      deliveryId: deliveryId,
    );

    // 5) update local cache (make sure it carries our deliveryId)
    final savedFixed = saved.copyWith(deliveryId: deliveryId);
    state = existing == null
        ? [...state, savedFixed]
        : state.map((b) => b.id == savedFixed.id ? savedFixed : b).toList();

    return savedFixed;
  }

  Future<void> deleteBatch(BatchRecord batch) async {
    await _service.deleteBatch(tenantId, batch.storeId, batch.id);
    state = state.where((b) => b.id != batch.id).toList();
  }

  Future<BatchRecord?> getById(String storeId, String batchId) =>
      _service.getBatchById(tenantId, storeId, batchId);

  Future<void> updateBatchQuantity({
    required String batchId,
    required int quantity,
  }) async {
    // Prefer local, fall back to backend read
    BatchRecord b;
    try {
      b = state.firstWhere((x) => x.id == batchId);
    } catch (_) {
      final guess = state.isNotEmpty ? state.first.storeId : null;
      if (guess == null) throw Exception('Batch not found: $batchId');
      final fetched = await getById(guess, batchId);
      if (fetched == null) throw Exception('Batch not found: $batchId');
      b = fetched;
    }

    final form = _FormFromExisting(b).copyWith(quantity: quantity);
    await save(
      itemId: b.itemId,
      itemType: b.itemType,
      form: form,
      existing: b,
      enteredByUid: b.enteredByUid ?? 'unknown',
      enteredByName: b.enteredByName ?? 'Unknown',
      enteredByEmail: b.enteredByEmail ?? 'unknown@user.com',
    );
  }

  // ── internals ────────────────────────────────────────────────

  // ⬇️ NEW
  Future<void> _linkBatchToDeliveryInFirestore({
    required String storeId,
    required String batchId,
    required String deliveryId,
  }) async {
    try {
      final doc = db.doc('tenants/$tenantId/stores/$storeId/batches/$batchId');
      await doc.set({
        'tenantId': tenantId, // required by banner provider
        'deliveryId': deliveryId, // used by banner/review
        'delivery_id': deliveryId, // optional: keep snake for parity
      }, SetOptions(merge: true));
    } catch (_) {
      // Non-fatal: banner may not show until doc updates.
    }
  }

  void _validateFormOrThrow(BatchLike f, {required bool isEditing}) {
    final errs = <String>[];
    final qty = int.tryParse(f.quantity.trim());
    if (qty == null || qty <= 0) {
      errs.add('Quantity must be a positive number.');
    }
    if ((f.storeId ?? '').trim().isEmpty) errs.add('Store is required.');
    if ((f.source ?? '').trim().isEmpty) errs.add('Source is required.');
    if (f.receivedDate == null) errs.add('Received date is required.');
    if (isEditing && f.editReason.trim().isEmpty) {
      errs.add('Reason for edit is required.');
    }
    if (errs.isNotEmpty) {
      throw Exception('Invalid batch:\n• ${errs.join('\n• ')}');
    }
  }

  BatchRecord _buildRecord({
    required String itemId,
    required ItemType itemType,
    required BatchLike form,
    required String deliveryId,
    required String enteredByUid,
    required String enteredByName,
    required String enteredByEmail,
    BatchRecord? existing,
  }) {
    final candidate = BatchRecord(
      id: existing?.id ?? form.generatedId(),
      tenantId: tenantId,
      storeId: form.storeId!.trim(),
      itemId: itemId,
      itemType: itemType,
      expiryDate: normalizeDate(form.expiryDate),
      receivedDate: normalizeDate(form.receivedDate),
      quantity: int.parse(form.quantity.trim()),
      deliveryId: deliveryId,
      enteredByUid: enteredByUid,
      enteredByName: enteredByName,
      enteredByEmail: enteredByEmail,
      source: form.source!.trim(),
      isEdited: existing != null,
      editReason: existing != null ? form.editReason.trim() : null,
    );

    final errors = batchRecordValidator(candidate.toRawMap());
    if (errors.isNotEmpty) {
      throw Exception('Invalid batch payload:\n• ${errors.join('\n• ')}');
    }
    return candidate;
  }

  Future<String> _ensureDeliverySession({
    required String storeId,
    required String source,
    required String enteredByName,
    required String enteredByEmail,
  }) async {
    final dse = ref.read(deliverySessionEngineProvider.notifier);
    await dse.ensureActive(
      enteredByName: enteredByName,
      enteredByEmail: enteredByEmail,
      source: source,
      storeId: storeId,
    );

    final deliveryId = ref.read(deliverySessionEngineProvider).deliveryId;
    if (deliveryId == null || deliveryId.isEmpty) {
      throw Exception('Failed to create/find delivery session.');
    }
    return deliveryId;
  }
}

/// Adapter to reuse an existing record as a form.
class _FormFromExisting implements BatchLike {
  _FormFromExisting(this.b);
  final BatchRecord b;

  @override
  DateTime? get receivedDate => b.receivedDate;
  @override
  DateTime? get expiryDate => b.expiryDate;
  @override
  String? get storeId => b.storeId;
  @override
  String? get source => b.source;
  @override
  String get quantity => b.quantity.toString();
  @override
  String get editReason => b.editReason ?? '';
  @override
  String generatedId() => b.id;

  _FormFromExisting copyWith({int? quantity}) => _MutForm(b, quantity);
}

class _MutForm extends _FormFromExisting {
  _MutForm(super.b, this._q);
  final int? _q;
  @override
  String get quantity => (_q ?? b.quantity).toString();
}
