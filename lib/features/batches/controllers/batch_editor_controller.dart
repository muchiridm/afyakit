import 'package:afyakit/features/batches/controllers/batch_editor_args.dart';
import 'package:afyakit/features/batches/screens/batch_editor_screen.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/users/user_manager/extensions/auth_user_x.dart';
import 'package:afyakit/users/user_manager/models/auth_user_model.dart';
import 'package:afyakit/users/user_operations/providers/current_user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/features/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/features/inventory_locations/inventory_location.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_type_enum.dart';
import 'package:afyakit/features/batches/controllers/batch_controller.dart';
import 'package:afyakit/features/records/delivery_sessions/controllers/delivery_session_controller.dart';
import 'package:afyakit/features/records/delivery_sessions/services/delivery_persistence_service.dart';

import 'package:afyakit/features/records/delivery_sessions/services/delivery_session_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/services/dialog_service.dart';

import 'batch_editor_state.dart';

final batchEditorProvider = StateNotifierProvider.autoDispose
    .family<BatchEditorController, BatchEditorState, BatchEditorArgs>(
      (ref, args) => BatchEditorController(
        ref,
        tenantId: args.tenantId,
        item: args.item,
        batch: args.batch,
        mode: args.mode,
      ),
    );

class BatchEditorController extends StateNotifier<BatchEditorState> {
  final Ref ref;
  final String tenantId;
  final BaseInventoryItem item;
  final BatchRecord? batch;
  final BatchEditorMode mode;

  BatchEditorController(
    this.ref, {
    required this.tenantId,
    required this.item,
    required this.batch,
    required this.mode,
  }) : super(
         BatchEditorState(
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

    if (mode == BatchEditorMode.edit) {
      state = state.copyWith(
        receivedDate: batch!.receivedDate,
        expiryDate: batch!.expiryDate,
        quantity: batch!.quantity.toString(),
        storeId: batch!.storeId,
        source: batch!.source,
        editReason: '', // start blank
      );
    } else {
      // Prefill only in ADD mode; do it after construction to avoid build churn
      Future.microtask(_prefillFromActiveDelivery);
    }
  }

  // ─────────────────────────────────────────────
  // 🔁 Prefill from active delivery (ADD mode only)
  // ─────────────────────────────────────────────
  Future<void> _prefillFromActiveDelivery() async {
    try {
      final user = ref.read(currentUserProvider).asData?.value;
      final email = (user?.email ?? user?.email ?? '').trim().toLowerCase();
      if (email.isEmpty) return;

      final session = await DeliverySessionService().findOpenSession(
        tenantId: tenantId,
        enteredByEmail: email,
      );
      if (session == null) return;

      // Only set defaults if the user hasn’t already picked values in this run
      final nextStore = state.storeId?.trim().isNotEmpty == true
          ? state.storeId
          : session.lastStoreId;
      final nextSource = state.source?.trim().isNotEmpty == true
          ? state.source
          : session.lastSource;

      if (nextStore != state.storeId || nextSource != state.source) {
        state = state.copyWith(storeId: nextStore, source: nextSource);
      }
    } catch (e) {
      // Non-fatal: just skip prefill if anything goes sideways
      debugPrint('⚠️ Prefill from active delivery failed: $e');
    }
  }

  // ─────────────────────────────────────────────
  // 🔍 Getters
  // ─────────────────────────────────────────────

  bool get isEditing => mode == BatchEditorMode.edit;

  bool get canSubmit {
    final qty = int.tryParse(state.quantity.trim());
    final baseValid =
        qty != null &&
        qty > 0 &&
        (state.storeId?.isNotEmpty ?? false) &&
        (state.source?.isNotEmpty ?? false) &&
        state.receivedDate != null;

    if (isEditing) {
      return baseValid && state.editReason.trim().isNotEmpty;
    }
    return baseValid;
  }

  // ─────────────────────────────────────────────
  // 🛠️ Update Methods
  // ─────────────────────────────────────────────

  void updateReceivedDate(DateTime? date) =>
      state = state.copyWith(receivedDate: date);

  void updateExpiryDate(DateTime? date) =>
      state = state.copyWith(expiryDate: date);

  void updateQuantity(String val) =>
      state = state.copyWith(quantity: val.trim());

  void updateStore(String? val) => state = state.copyWith(storeId: val?.trim());

  void updateSource(String? val) => state = state.copyWith(source: val?.trim());

  void updateEditReason(String val) =>
      state = state.copyWith(editReason: val.trim());

  // ─────────────────────────────────────────────
  // 🏪 Store & Source Options
  // ─────────────────────────────────────────────

  List<InventoryLocation> getStoreOptions(
    List<InventoryLocation> allStores,
    AuthUser user,
  ) {
    final current = state.storeId?.trim();

    final allowed = allStores.where((s) => user.canAccessStore(s.id)).toList();

    final currentMissing =
        isEditing && current != null && allowed.every((s) => s.id != current);

    if (currentMissing) {
      allowed.add(
        InventoryLocation(
          id: current,
          tenantId: tenantId,
          name: 'Unknown Store',
          type: InventoryLocationType.store,
          createdBy: user.displayName,
          createdOn: DateTime.now(),
        ),
      );
    }

    // Don’t mutate state during build; defer clearing invalid current
    if (!isEditing &&
        current != null &&
        current.isNotEmpty &&
        allowed.every((s) => s.id != current)) {
      Future.microtask(() {
        state = state.copyWith(storeId: null);
      });
    }

    return allowed;
  }

  List<String> getStoreNames(List<InventoryLocation> stores) {
    final names = stores.map((e) => e.name).toSet();
    final current = state.storeId;
    if (current != null && current.isNotEmpty) names.add(current);
    return names.toList()..sort();
  }

  List<String> getSourceOptions(List<InventoryLocation> sources) {
    final options = <String>{
      ...sources.map((s) => s.name),
      if (state.source?.isNotEmpty ?? false) state.source!,
    };
    return options.toList()..sort();
  }

  // ─────────────────────────────────────────────
  // 🧑🏾‍💻 Permissions
  // ─────────────────────────────────────────────

  bool canEdit(AuthUser user) {
    final storeId = state.storeId?.trim();
    return storeId != null && user.canManageStoreById(storeId);
  }

  // ─────────────────────────────────────────────
  // 💾 Save Logic
  // ─────────────────────────────────────────────

  Future<void> save(BuildContext context) async {
    final quantity = int.tryParse(state.quantity.trim());

    if (quantity == null || quantity <= 0) {
      SnackService.showError('Enter a valid quantity');
      return;
    }

    if ((state.storeId?.isEmpty ?? true)) {
      SnackService.showError('Please select a store');
      return;
    }

    if ((state.source?.isEmpty ?? true)) {
      SnackService.showError('Please select a source');
      return;
    }

    if (state.receivedDate == null) {
      SnackService.showError('Please pick a received date');
      return;
    }

    if (isEditing && state.editReason.trim().isEmpty) {
      SnackService.showError('Please enter a reason for editing');
      return;
    }

    if (item.id == null || item.id!.isEmpty) {
      SnackService.showError('❌ Item is missing a valid ID');
      return;
    }

    final deliveryController = ref.read(
      deliverySessionControllerProvider.notifier,
    );
    final user = ref.read(currentUserProvider).asData?.value;
    final enteredByEmail = (user?.email ?? user?.email ?? 'unknown@user.com')
        .trim();
    final enteredByName = user?.displayName.trim() ?? 'Unknown';

    await deliveryController.ensureActiveSession(
      enteredByName: enteredByName,
      enteredByEmail: enteredByEmail,
      source: state.source!.trim(),
      storeId: state.storeId?.trim(),
    );

    final deliveryId = deliveryController.state.deliveryId;
    if (deliveryId == null || deliveryId.isEmpty) {
      SnackService.showError('❌ Failed to create delivery session.');
      return;
    }

    final newBatch = BatchRecord(
      id: batch?.id ?? const Uuid().v4(),
      itemId: item.id!,
      itemType: item.type,
      storeId: state.storeId!.trim(),
      expiryDate: state.expiryDate,
      receivedDate: state.receivedDate!,
      quantity: quantity,
      deliveryId: deliveryId,
      enteredByUid: enteredByEmail,
      source: state.source!.trim(),
      isEdited: isEditing,
      editReason: isEditing ? state.editReason.trim() : null,
    );

    final tenantId = ref.read(tenantIdProvider);
    final controller = ref.read(batchControllerProvider(tenantId).notifier);

    try {
      if (isEditing) {
        await controller.updateBatch(newBatch);
        SnackService.showSuccess('Batch updated!');
      } else {
        await controller.createBatch(newBatch);
        SnackService.showSuccess('Batch added!');
      }

      // Persist the whole temp session snapshot, as you already do
      await DeliveryPersistenceService.persistAll(
        tenantId,
        deliveryController.state,
      );

      // ⬇️ NEW: write “last used” prefs back to the temp session
      await DeliverySessionService().updateLastPrefs(
        tenantId: tenantId,
        deliveryId: deliveryId,
        lastStoreId: state.storeId?.trim(),
        lastSource: state.source?.trim(),
      );

      if (context.mounted) Navigator.of(context).pop();
    } catch (e, stack) {
      debugPrint('❌ Error saving batch: $e');
      debugPrint('🧱 Stack trace:\n$stack');
      SnackService.showError('Error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // 🗑 Delete Logic
  // ─────────────────────────────────────────────

  Future<void> delete(BuildContext context) async {
    if (!isEditing || batch == null) return;

    final confirmed = await DialogService.confirm(
      title: 'Delete Batch?',
      content: 'This action cannot be undone.',
      confirmText: 'Delete',
    );

    if (confirmed == true) {
      await ref
          .read(batchControllerProvider(tenantId).notifier)
          .deleteBatch(batch!);
      SnackService.showSuccess('Batch deleted!');
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  // ─────────────────────────────────────────────
  // 🧠 Helpers
  // ─────────────────────────────────────────────

  static DateTime _initReceivedDate(BatchRecord? batch, BatchEditorMode mode) {
    return batch?.receivedDate ?? DateTime.now();
  }
}
