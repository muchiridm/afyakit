// lib/features/batches/controllers/batch_controller.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/batches/controllers/batch_args.dart';
import 'package:afyakit/core/batches/controllers/batch_engine.dart';
import 'package:afyakit/core/batches/controllers/batch_state.dart';
import 'package:afyakit/core/batches/models/batch_record.dart';
import 'package:afyakit/core/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/core/records/delivery_sessions/controllers/delivery_session_engine.dart';
import 'package:afyakit/core/auth_users/providers/current_user_session_providers.dart';
import 'package:afyakit/shared/services/snack_service.dart';

final batchEditorProvider = StateNotifierProvider.autoDispose
    .family<BatchEditorController, BatchState, BatchArgs>(
      (ref, args) => BatchEditorController(
        ref,
        tenantId: args.tenantId,
        item: args.item,
        batch: args.batch,
        mode: args.mode,
      ),
    );

class BatchEditorController extends StateNotifier<BatchState> {
  final Ref ref;
  final String tenantId;
  final BaseInventoryItem item;
  final BatchRecord? batch;
  final BatchEditorMode mode;

  Timer? _ensureDebounce;

  BatchEditorController(
    this.ref, {
    required this.tenantId,
    required this.item,
    required this.batch,
    required this.mode,
  }) : super(
         BatchState(
           receivedDate: _initReceivedDate(batch, mode),
           expiryDate: batch?.expiryDate,
           storeId: batch?.storeId.trim(),
           source: batch?.source?.trim(),
           quantity: batch?.quantity.toString() ?? '',
         ),
       ) {
    if (mode == BatchEditorMode.edit && batch == null) {
      throw Exception('❌ Batch cannot be null in edit mode');
    }
    if (mode == BatchEditorMode.add) {
      // Prefill from delivery engine state (engine auto-restores on init)
      Future.microtask(_prefillFromDeliveryEngine);
    }
    ref.onDispose(() => _ensureDebounce?.cancel());
  }

  bool get isEditing => mode == BatchEditorMode.edit;

  // ── Prefill from the Delivery Session Engine ─────────────────
  Future<void> _prefillFromDeliveryEngine() async {
    final ds = ref.read(deliverySessionEngineProvider);
    if (!ds.isActive) return;

    final nextStore = (state.storeId?.trim().isNotEmpty ?? false)
        ? state.storeId
        : ds.lastStoreId;
    final nextSource = (state.source?.trim().isNotEmpty ?? false)
        ? state.source
        : ds.lastSource;

    if (nextStore != state.storeId || nextSource != state.source) {
      state = state.copyWith(storeId: nextStore, source: nextSource);
    }

    // If both are present after prefill, try to ensure a session
    _ensureActiveIfReady();
  }

  // ── Debounced ensureActive via Delivery Session Engine ───────
  void _ensureActiveIfReady() {
    final s = (state.storeId ?? '').trim();
    final src = (state.source ?? '').trim();
    if (s.isEmpty || src.isEmpty) return;

    _ensureDebounce?.cancel();
    _ensureDebounce = Timer(const Duration(milliseconds: 200), () async {
      final user = await ref.read(currentUserFutureProvider.future);
      final email = (user?.email ?? '').trim().toLowerCase();
      final name = (user?.displayName ?? 'Unknown').trim();
      if (email.isEmpty) return;

      await ref
          .read(deliverySessionEngineProvider.notifier)
          .ensureActive(
            enteredByName: name,
            enteredByEmail: email,
            source: src,
            storeId: s,
          );
    });
  }

  // ⬇️ NEW: immediate ensure (non-debounced) used in save()
  Future<void> _ensureActiveNowIfPossible({
    required String email,
    required String name,
  }) async {
    final s = (state.storeId ?? '').trim();
    final src = (state.source ?? '').trim();
    if (s.isEmpty || src.isEmpty || email.isEmpty) return;
    await ref
        .read(deliverySessionEngineProvider.notifier)
        .ensureActive(
          enteredByName: name,
          enteredByEmail: email,
          source: src,
          storeId: s,
        );
  }

  // ── Mutations (auto-ensure when both fields present) ─────────
  void updateReceivedDate(DateTime? v) =>
      state = state.copyWith(receivedDate: v);

  void updateExpiryDate(DateTime? v) => state = state.copyWith(expiryDate: v);

  void updateQuantity(String v) => state = state.copyWith(quantity: v.trim());

  void updateStore(String? v) {
    state = state.copyWith(storeId: (v ?? '').trim());
    _ensureActiveIfReady();
  }

  void updateSource(String? v) {
    state = state.copyWith(source: (v ?? '').trim());
    _ensureActiveIfReady();
  }

  void updateEditReason(String v) =>
      state = state.copyWith(editReason: v.trim());

  // ── Save via BatchEngine (engine ensures session again) ──────
  Future<bool> save() async {
    final user = await ref.read(currentUserFutureProvider.future);
    final email = (user?.email ?? '').trim().toLowerCase();
    final name = (user?.displayName ?? 'Unknown').trim();
    final uid = (user?.uid ?? 'unknown').trim();

    if (email.isEmpty) {
      SnackService.showError('You must be signed in to record deliveries.');
      return false;
    }

    final id = item.id;
    if (id == null || id.isEmpty) {
      SnackService.showError('❌ Item is missing a valid ID');
      return false;
    }

    try {
      // Ensure immediately (don’t rely on the debounce timer)
      await _ensureActiveNowIfPossible(email: email, name: name);

      final engine = ref.read(batchEngineProvider(tenantId).notifier);
      await engine.save(
        itemId: id,
        itemType: item.type,
        form: state,
        existing: batch,
        enteredByUid: uid,
        enteredByName: name,
        enteredByEmail: email,
      );

      // ⬇️ NEW: remember last used to the temp session
      await ref
          .read(deliverySessionEngineProvider.notifier)
          .rememberLastUsed(
            lastStoreId: state.storeId?.trim(),
            lastSource: state.source?.trim(),
          );

      SnackService.showSuccess(isEditing ? 'Batch updated!' : 'Batch added!');
      return true;
    } catch (e, _) {
      SnackService.showError('Error: $e');
      return false;
    }
  }

  Future<bool> delete() async {
    if (!isEditing || batch == null) return false;
    try {
      final engine = ref.read(batchEngineProvider(tenantId).notifier);
      await engine.deleteBatch(batch!);
      SnackService.showSuccess('Batch deleted!');
      return true;
    } catch (e, _) {
      SnackService.showError('Error: $e');
      return false;
    }
  }

  static DateTime _initReceivedDate(BatchRecord? b, BatchEditorMode m) =>
      b?.receivedDate ?? DateTime.now();
}
