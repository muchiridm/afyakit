// lib/features/inventory_view/controllers/inventory_view_controller.dart
import 'package:afyakit/core/batches/controllers/batch_args.dart';
import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/extensions/auth_user_x.dart';

import 'package:afyakit/core/batches/models/batch_record.dart';
import 'package:afyakit/core/batches/providers/batch_records_stream_provider.dart';

import 'package:afyakit/core/inventory/extensions/item_type_x.dart';
import 'package:afyakit/core/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/core/inventory/providers/item_stream_providers.dart';
import 'package:afyakit/core/inventory/screens/inventory_editor_screen.dart';

import 'package:afyakit/core/records/deliveries/controllers/delivery_session_controller.dart';

import 'package:afyakit/core/batches/screens/batch_editor_screen.dart';
import 'package:afyakit/core/inventory_view/controllers/inventory_view_state.dart';

import 'package:afyakit/hq/tenants/providers/tenant_slug_provider.dart';
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
      final tenantId = ref.watch(tenantSlugProvider);
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
  Future<void> startAddBatch(
    BuildContext context,
    BaseInventoryItem item,
    AuthUser user,
  ) async {
    if (user.tenantId.isEmpty) {
      SnackService.showError('❌ Missing tenant ID for this user');
      return;
    }

    // Controller is the UI façade over the engine.
    final ds = ref.read(deliverySessionControllerProvider);

    // Read once (no rebuilds here).
    final session = ds.readState();

    final enteredByName = (user.displayName.trim().isNotEmpty)
        ? user.displayName.trim()
        : user.email.trim();
    final enteredByEmail = user.email.trim();

    // Ensure there’s an active session (engine will resume or start new).
    if (!session.isActive) {
      await ds.ensureActive(
        enteredByName: enteredByName,
        enteredByEmail: enteredByEmail,
        source: '', // no source yet; engine ignores empty
        storeId: null, // provide one if you already know it
      );
    }

    if (!context.mounted) return;

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
