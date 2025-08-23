// lib/features/inventory_view/controllers/inventory_view_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/auth_users/models/auth_user_model.dart';
import 'package:afyakit/features/auth_users/user_manager/extensions/auth_user_x.dart';

import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/features/batches/providers/batch_records_stream_provider.dart';

import 'package:afyakit/features/inventory/models/item_type_enum.dart';
import 'package:afyakit/features/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/features/inventory/providers/item_stream_providers.dart';
import 'package:afyakit/features/inventory/screens/inventory_editor_screen.dart';

import 'package:afyakit/features/records/delivery_sessions/controllers/delivery_session_controller.dart';

import 'package:afyakit/features/batches/screens/batch_editor_screen.dart';
import 'package:afyakit/features/inventory_view/controllers/inventory_view_state.dart';

import 'package:afyakit/features/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/shared/providers/firestore_tenant_guard.dart';
import 'package:afyakit/shared/services/sku_batch_matcher.dart';
import 'package:afyakit/shared/services/snack_service.dart';

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

  // ─────────────────────────────────────────────
  // Init: wait for tenant guard, then wire streams
  // ─────────────────────────────────────────────
  void _initialize() {
    // Ensure token claims are synced to the selected tenant before any CG reads.
    ref
        .read(firestoreTenantGuardProvider.future)
        .then((_) {
          if (!mounted) return;
          _startItemsStream();
          _startBatchesStream();
          if (kDebugMode) {
            debugPrint('🛡️ [invVC] tenant guard OK → $tenantId, type=$type');
          }
        })
        .catchError((e, st) {
          _itemsLoading = _batchesLoading = false;
          if (!mounted) return;
          state = state.copyWith(isLoading: false, error: e.toString());
          if (kDebugMode) {
            debugPrint('🔥 [invVC] guard error: $e');
            debugPrint('🧱 [invVC] stack:\n$st');
          }
        });
  }

  void _startItemsStream() {
    final itemsProvider = switch (type) {
      ItemType.medication => medicationItemsStreamProvider(tenantId),
      ItemType.consumable => consumableItemsStreamProvider(tenantId),
      ItemType.equipment => equipmentItemsStreamProvider(tenantId),
      ItemType.unknown => throw StateError('Unknown item type'),
    };

    _itemsSub = ref.listen<AsyncValue<List<BaseInventoryItem>>>(itemsProvider, (
      prev,
      next,
    ) {
      next.when(
        loading: () {
          _itemsLoading = true;
          _applyLoading();
          if (kDebugMode) debugPrint('⏳ [invVC] items loading…');
        },
        error: (e, st) {
          _itemsLoading = false;
          if (!mounted) return;
          state = state.copyWith(isLoading: false, error: e.toString());
          if (kDebugMode) {
            debugPrint('🔥 [invVC] items error: $e');
            debugPrint('🧱 [invVC] stack:\n$st');
          }
        },
        data: (items) {
          _itemsLoading = false;
          if (kDebugMode) {
            debugPrint('📦 [invVC] items loaded: ${items.length} (type=$type)');
          }
          _rebuild(items: items);
        },
      );
    }, fireImmediately: true);
  }

  void _startBatchesStream() {
    _batchesSub = ref.listen<AsyncValue<List<BatchRecord>>>(
      batchRecordsStreamProvider(tenantId),
      (prev, next) {
        next.when(
          loading: () {
            _batchesLoading = true;
            _applyLoading();
            if (kDebugMode) debugPrint('⏳ [invVC] batches loading…');
          },
          error: (e, st) {
            _batchesLoading = false;
            if (!mounted) return;
            state = state.copyWith(isLoading: false, error: e.toString());
            if (kDebugMode) {
              debugPrint('🔥 [invVC] batches error: $e');
              debugPrint('🧱 [invVC] stack:\n$st');
            }
          },
          data: (batches) {
            _batchesLoading = false;
            if (kDebugMode) {
              debugPrint('📦 [invVC] batches loaded: ${batches.length}');
            }
            _rebuild(batches: batches);
          },
        );
      },
      fireImmediately: true,
    );
  }

  void _applyLoading() {
    final isLoading = _itemsLoading || _batchesLoading;
    if (!mounted) return;
    if (state.isLoading != isLoading) {
      state = state.copyWith(isLoading: isLoading, error: null);
    }
  }

  void _rebuild({List<BaseInventoryItem>? items, List<BatchRecord>? batches}) {
    final newItems = items ?? state.items;
    final newBatches = batches ?? state.batches;

    final matcher = SkuBatchMatcher.from(items: newItems, batches: newBatches);

    if (!mounted) return;
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
  void setQuery(String val) {
    final q = val.trim();
    if (q == state.query) return;
    state = state.copyWith(query: q);
  }

  void toggleSort() =>
      state = state.copyWith(sortAscending: !state.sortAscending);

  // ─────────────────────────────────────────────
  // Navigation helpers
  // ─────────────────────────────────────────────
  void startAddBatch(
    BuildContext context,
    BaseInventoryItem item,
    AuthUser user,
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
        sources: const [],
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
    BaseInventoryItem item,
    AuthUser user,
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

  bool canEditBatch(BatchRecord batch, AuthUser user) =>
      user.canManageBatch(batch);

  @override
  void dispose() {
    _itemsSub?.close();
    _batchesSub?.close();
    super.dispose();
  }
}
