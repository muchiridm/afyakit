import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/inventory_view/controllers/inventory_view_state.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';

import 'package:afyakit/features/inventory/models/item_type_enum.dart';
import 'package:afyakit/features/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/features/batches/models/batch_record.dart';

import 'package:afyakit/features/inventory/providers/item_streams/medication_items_stream_provider.dart';
import 'package:afyakit/features/inventory/providers/item_streams/consumable_items_stream_provider.dart';
import 'package:afyakit/features/inventory/providers/item_streams/equipment_items_stream_provider.dart';
import 'package:afyakit/shared/providers/stock/batch_records_stream_provider.dart';

import 'package:afyakit/shared/services/sku_batch_matcher.dart';
import 'package:afyakit/shared/services/snack_service.dart';

import 'package:afyakit/features/batches/screens/batch_editor_screen.dart';
import 'package:afyakit/features/inventory/screens/inventory_editor_screen.dart';
import 'package:afyakit/users/models/combined_user_model.dart';
import 'package:afyakit/users/extensions/combined_user_x.dart';
import 'package:afyakit/features/records/delivery_sessions/controllers/delivery_session_controller.dart';

/// 🎯 ViewController family — scoped per ItemType
/// IMPORTANT: not autoDispose so view prefs persist across navigation.
final inventoryViewControllerFamily =
    StateNotifierProvider.family<
      InventoryViewController,
      InventoryViewState,
      ItemType
    >((ref, type) {
      final tenantId = ref.watch(tenantIdProvider);
      return InventoryViewController(ref, tenantId, type);
    });

class InventoryViewController extends StateNotifier<InventoryViewState> {
  final Ref ref;
  final String tenantId;
  final ItemType type;

  ProviderSubscription<AsyncValue<List<BaseInventoryItem>>>? _itemsSub;
  ProviderSubscription<AsyncValue<List<BatchRecord>>>? _batchesSub;

  bool _itemsLoading = true;
  bool _batchesLoading = true;

  InventoryViewController(this.ref, this.tenantId, this.type)
    : super(InventoryViewState.initialFor(type)) {
    _initialize();
  }

  void _initialize() {
    // ITEMS stream (by type)
    final itemsProvider = switch (type) {
      ItemType.medication => medicationItemsStreamProvider(tenantId),
      ItemType.consumable => consumableItemsStreamProvider(tenantId),
      ItemType.equipment => equipmentItemsStreamProvider(tenantId),
      ItemType.unknown => throw Exception('Unknown item type'),
    };

    _itemsSub = ref.listen<AsyncValue<List<BaseInventoryItem>>>(itemsProvider, (
      prev,
      next,
    ) {
      next.when(
        loading: () {
          _itemsLoading = true;
          _applyLoading();
        },
        error: (e, _) {
          _itemsLoading = false;
          state = state.copyWith(isLoading: false, error: e.toString());
        },
        data: (items) {
          _itemsLoading = false;
          _rebuild(items: items);
        },
      );
    }, fireImmediately: true);

    // BATCHES stream
    _batchesSub = ref.listen<AsyncValue<List<BatchRecord>>>(
      batchRecordsStreamProvider(tenantId),
      (prev, next) {
        next.when(
          loading: () {
            _batchesLoading = true;
            _applyLoading();
          },
          error: (e, _) {
            _batchesLoading = false;
            state = state.copyWith(isLoading: false, error: e.toString());
          },
          data: (batches) {
            _batchesLoading = false;
            _rebuild(batches: batches);
          },
        );
      },
      fireImmediately: true,
    );
  }

  void _applyLoading() {
    final isLoading = _itemsLoading || _batchesLoading;
    if (state.isLoading != isLoading) {
      state = state.copyWith(isLoading: isLoading, error: null);
    }
  }

  void _rebuild({List<BaseInventoryItem>? items, List<BatchRecord>? batches}) {
    final newItems = items ?? state.items;
    final newBatches = batches ?? state.batches;

    final matcher = SkuBatchMatcher.from(items: newItems, batches: newBatches);

    // 🔒 Preserve query/sort; patch just the data slices
    state = state.copyWith(
      items: newItems,
      batches: newBatches,
      matcher: matcher,
      isLoading: _itemsLoading || _batchesLoading,
      error: null,
    );
  }

  // ─────────────────────────────────────────────
  // View prefs
  // ─────────────────────────────────────────────
  void setQuery(String val) => state = state.copyWith(query: val);
  void toggleSort() =>
      state = state.copyWith(sortAscending: !state.sortAscending);

  // ─────────────────────────────────────────────
  // Navigation helpers (unchanged)
  // ─────────────────────────────────────────────
  void startAddBatch(
    BuildContext context,
    BaseInventoryItem item,
    CombinedUser user,
  ) {
    if (user.tenantId.isEmpty) {
      SnackService.showError('❌ Missing tenant ID for this user');
      return;
    }

    final session = ref.read(deliverySessionControllerProvider);
    final sessionController = ref.read(
      deliverySessionControllerProvider.notifier,
    );

    final enteredByName = user.displayName.trim().isNotEmpty
        ? user.displayName.trim()
        : user.email;
    final enteredByEmail = user.email;

    if (!session.isActive) {
      sessionController.startNew(
        enteredByName: enteredByName,
        enteredByEmail: enteredByEmail,
        sources: [], // No assumption about source
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BatchEditorScreen(
          tenantId: user.tenantId,
          item: item,
          mode: BatchEditorMode.add,
          batch: null,
        ),
      ),
    );
  }

  void editBatch(
    BuildContext context,
    BatchRecord batch,
    dynamic item,
    CombinedUser user,
  ) {
    if (user.tenantId.isEmpty) {
      SnackService.showError('❌ Missing tenant ID');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BatchEditorScreen(
          tenantId: user.tenantId,
          item: item,
          mode: BatchEditorMode.edit,
          batch: batch,
        ),
      ),
    );
  }

  void createItem(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryEditorScreen(item: null, itemType: type),
      ),
    );
  }

  bool canEditBatch(BatchRecord batch, CombinedUser user) =>
      user.canManageBatch(batch);

  @override
  void dispose() {
    _itemsSub?.close();
    _batchesSub?.close();
    super.dispose();
  }
}
