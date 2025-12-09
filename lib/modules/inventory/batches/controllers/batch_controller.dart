// lib/features/batches/controllers/batch_controller.dart
import 'dart:async';
import 'package:afyakit/modules/core/auth_users/providers/current_user_providers.dart';
import 'package:afyakit/modules/inventory/locations/inventory_location.dart';
import 'package:afyakit/modules/inventory/locations/inventory_location_controller.dart';
import 'package:afyakit/modules/inventory/locations/inventory_location_type_enum.dart';
import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_location_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/modules/inventory/batches/controllers/batch_args.dart';
import 'package:afyakit/modules/inventory/batches/controllers/batch_engine.dart';
import 'package:afyakit/modules/inventory/batches/controllers/batch_state.dart';
import 'package:afyakit/modules/inventory/batches/models/batch_record.dart';
import 'package:afyakit/modules/inventory/items/models/items/base_inventory_item.dart';
import 'package:afyakit/modules/inventory/records/deliveries/controllers/delivery_session_engine.dart';
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
      final user = ref.read(currentUserValueProvider);
      final phone = (user?.phoneNumber ?? '').trim();
      final name = (user?.displayName ?? 'Unknown').trim();

      if (phone.isEmpty) return;

      await ref
          .read(deliverySessionEngineProvider.notifier)
          .ensureActive(
            enteredByName: name,
            // still named enteredByEmail in engine, but we now pass WhatsApp number
            enteredByEmail: phone,
            source: src,
            storeId: s,
          );
    });
  }

  // ⬇️ immediate ensure (non-debounced) used in save()
  Future<void> _ensureActiveNowIfPossible({
    required String phone,
    required String name,
  }) async {
    final s = (state.storeId ?? '').trim();
    final src = (state.source ?? '').trim();
    if (s.isEmpty || src.isEmpty || phone.isEmpty) return;

    await ref
        .read(deliverySessionEngineProvider.notifier)
        .ensureActive(
          enteredByName: name,
          // same here – backend field name unchanged
          enteredByEmail: phone,
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
    final user = ref.read(currentUserValueProvider);
    final phone = (user?.phoneNumber ?? '').trim();
    final name = (user?.displayName ?? 'Unknown').trim();
    final uid = (user?.uid ?? 'unknown').trim();

    if (phone.isEmpty) {
      SnackService.showError(
        'You must be signed in with a WhatsApp number to record deliveries.',
      );
      return false;
    }

    final id = item.id;
    if (id == null || id.isEmpty) {
      SnackService.showError('❌ Item is missing a valid ID');
      return false;
    }

    try {
      // Ensure immediately (don’t rely on the debounce timer)
      await _ensureActiveNowIfPossible(phone: phone, name: name);

      final engine = ref.read(batchEngineProvider(tenantId).notifier);
      await engine.save(
        itemId: id,
        itemType: item.type,
        form: state,
        existing: batch,
        enteredByUid: uid,
        enteredByName: name,
        // still called enteredByEmail in engine; value is WA number
        enteredByEmail: phone,
      );

      // remember last used to the temp session
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

  Future<bool> delete({BuildContext? context}) async {
    if (!isEditing || batch == null) return false;

    // Resolve a friendly store name (fallback to ID if lists not ready)
    final stores = ref
        .read(inventoryLocationProvider(InventoryLocationType.store))
        .maybeWhen(
          data: (d) => d.cast<InventoryLocation>(),
          orElse: () => <InventoryLocation>[],
        );
    final dispensaries = ref
        .read(inventoryLocationProvider(InventoryLocationType.dispensary))
        .maybeWhen(
          data: (d) => d.cast<InventoryLocation>(),
          orElse: () => <InventoryLocation>[],
        );
    final storeName = resolveLocationName(batch!.storeId, stores, dispensaries);

    // Ask the user first (uses passed context or navigatorKey fallback).
    final ok = await DialogService.confirm(
      context: context,
      title: 'Delete batch?',
      content:
          'This will permanently remove batch "${batch!.id}" from "$storeName".\n'
          'This cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );
    if (!ok) return false;

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
