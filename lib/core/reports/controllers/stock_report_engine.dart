import 'dart:async';
import 'package:afyakit/core/inventory_locations/inventory_location.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_type_enum.dart';
import 'package:afyakit/core/records/reorder/services/reorder_service.dart';
import 'package:afyakit/core/reports/services/sku_field_updater.dart';
import 'package:afyakit/core/reports/services/stock_report_exporter.dart';
import 'package:afyakit/core/reports/services/stock_report_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/reports/extensions/stock_view_mode_enum.dart';
import 'package:afyakit/core/reports/extensions/stock_view_mode_x.dart';
import 'package:afyakit/core/reports/extensions/stock_order_filter_enum.dart';
import 'package:afyakit/core/reports/extensions/stock_availability_filter_enum.dart';
import 'package:afyakit/core/reports/extensions/stock_expiry_filter_option_enum.dart';

import 'package:afyakit/core/inventory/models/item_type_enum.dart';
import 'package:afyakit/core/reports/controllers/stock_report_state.dart';
import 'package:afyakit/core/reports/providers/stock_report_services_providers.dart';

final stockReportEngineProvider =
    StateNotifierProvider<StockReportEngine, StockReportState>((ref) {
      final engine = StockReportEngine(ref)..loadInitialViewMode();
      ref.onDispose(() async {
        engine.cleanup();
        if (engine._syncService.hasPending) {
          await engine.flushPendingUpdates();
        }
      });
      return engine;
    });

class StockReportEngine extends StateNotifier<StockReportState> {
  final Ref ref;
  bool _disposed = false;
  Timer? _searchDebounce;
  Timer? _autoSaveTimer;

  StockReportEngine(this.ref) : super(StockReportState.initial());

  // Services via ref
  StockReportLoader get _loader => ref.read(stockReportLoaderProvider);
  SkuFieldUpdater get _syncService => ref.read(skuFieldSyncServiceProvider);
  ReorderService get _reorderService => ref.read(reorderServiceProvider);

  // 🔄 Lifecycle
  void cleanup() {
    _disposed = true;
    _searchDebounce?.cancel();
    _autoSaveTimer?.cancel();
  }

  @override
  bool get mounted => !_disposed;

  void setState(StockReportState next) {
    if (mounted) state = next;
  }

  // 📊 UI State Access
  StockReportState get publicState => state;
  bool get reportReady => state.reportReady;
  List<ItemType> get validTabs =>
      ItemType.values.where((e) => e != ItemType.unknown).toList();

  // 🔄 View Mode
  Future<void> setViewMode(StockViewMode mode) async {
    if (!mounted) return;
    await _withSyncing(() async {
      if (_syncService.hasPending) await flushPendingUpdates();
      final newState = await _loader.loadViewMode(
        mode: mode,
        currentState: state,
      );
      setState(newState);
      _applyFiltersForCurrentTab(newState);
    });
  }

  Future<void> reloadCurrentViewMode() => setViewMode(state.viewMode);

  Future<void> loadInitialViewMode() async {
    final reset = _resetFilters(state);
    setState(reset);
    await setViewMode(reset.viewMode);
  }

  // 🧹 Filters
  StockReportState _resetFilters(StockReportState s) => s.copyWith(
    searchQuery: '',
    selectedStores: {},
    stockAvailabilityFilter: StockAvailabilityFilter.all,
    expiryFilter: ExpiryFilterOption.none,
    filter: StockOrderFilter.none,
    sortStack: s.sortStack.isEmpty
        ? [(StockSortColumn.name, true), (StockSortColumn.group, true)]
        : s.sortStack,
  );

  void setTab(int index) {
    if (!mounted || index < 0 || index >= validTabs.length) return;
    final next = state.copyWith(tabIndex: index);
    setState(next);
    _applyFiltersForCurrentTab(next);
  }

  void setSearchQuery(String query) {
    if (!mounted) return;
    _searchDebounce?.cancel();
    // update state with new query
    state = state.copyWith(searchQuery: query);

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      // Re-apply filters for the current tab & mode (this updates the right bucket)
      _applyFiltersForCurrentTab(state);
    });
  }

  void _applyFiltersForCurrentTab(StockReportState s) {
    final tabType = s.currentTabType;
    _loader.applyFiltersToTab(s, tabType, updateState: _updateState);
    if (s.viewMode.isGrouped) {
      _loader.applyFiltersToGroupedReports(
        state: s,
        itemType: tabType,
        updateState: _updateState,
      );
    }
  }

  void applyFiltersToCurrentView() {
    if (state.viewMode.isFlatList) {
      _loader.applyFilters(state, updateState: setState);
    } else {
      rebuildGroupedFilters();
    }
  }

  void rebuildGroupedFilters() {
    final s = state;
    if (s.viewMode == StockViewMode.groupedPerStore) {
      // build & filter the per-store list
      final grouped = _loader.buildPerStoreFromRaw(s.rawTabReports, s);
      setState(s.copyWith(groupedPerStoreReports: grouped));
    } else {
      // build & filter the per-sku list
      final grouped = _loader.buildGroupedFromRaw(s.rawTabReports, s);
      setState(s.copyWith(groupedPerSkuReports: grouped));
    }
    // ensure final pass through your general filter pipeline
    _loader.applyFilters(state, updateState: _updateState);
  }

  // ✍🏽 SKU Edits
  void updateSkuField({
    required String itemId,
    required ItemType type,
    required String field,
    required dynamic newValue,
  }) {
    if (!mounted) return;

    final updated = _syncService.updateLocally(
      current: _loader.getCurrentEditableList(state, type),
      itemId: itemId,
      field: field,
      value: newValue,
      type: type,
    );

    if (updated != null) {
      final updatedList = _loader.updateListInState(state, type, [updated]);
      setState(updatedList);

      // ✅ Flush immediately after local update
      unawaited(flushPendingUpdates());
    }
  }

  // ☁️ Sync
  Future<void> flushPendingUpdates() async {
    if (!mounted) return;

    final updatedReports = await _syncService.flush();

    if (updatedReports.isEmpty) return;

    // 1️⃣ Patch rawTabReports (single source of truth)
    final patched = _loader.patchRawReports(
      current: state.rawTabReports,
      updates: updatedReports,
    );

    // 2️⃣ Update state with new rawTabReports
    final newState = state.copyWith(rawTabReports: patched);
    setState(newState);

    // 3️⃣ Re-apply filters to sync derived views
    _loader.applyFilters(newState, updateState: _updateState);
  }

  // 🔁 Refresh
  Future<void> refresh() async {
    if (!mounted) return;
    await _withSyncing(() async {
      if (_syncService.hasPending) await flushPendingUpdates();
      final cleared = _resetFilters(state);
      setState(cleared);
      final refreshed = await _loader.loadViewMode(
        mode: cleared.viewMode,
        currentState: cleared,
      );
      setState(refreshed);
    });
  }

  // 📤 Export & Orders
  Future<void> exportReport(BuildContext context) async {
    if (!mounted) return;

    // 1) Use exactly what's on screen (already filtered)
    final reports = state.currentFilteredReports;

    // 2) Load resolver lists once (read, not watch)
    final stores = ref
        .read(inventoryLocationProvider(InventoryLocationType.store))
        .maybeWhen(data: (d) => d, orElse: () => const <InventoryLocation>[]);
    final dispensaries = ref
        .read(inventoryLocationProvider(InventoryLocationType.dispensary))
        .maybeWhen(data: (d) => d, orElse: () => const <InventoryLocation>[]);

    // 3) Export with name resolution
    await StockReportExporter.export(
      context: context,
      reports: reports, // ✅ filtered list only
      viewMode: state.viewMode,
      itemType: state.currentTabType,
      stores: stores, // ✅ for resolveLocationName(...)
      dispensaries: dispensaries, // ✅ for resolveLocationName(...)
    );
  }

  Future<void> saveProposedOrders({
    required String exportedByUid,
    required String exportedByName,
    String? note,
  }) async {
    final allRecords = state.rawTabReports.values.expand((e) => e).toList();

    await _reorderService.saveReportOrder(
      allRecords,
      type: state.currentTabType,
      exportedByUid: exportedByUid,
      exportedByName: exportedByName,
      note: note,
    );
  }

  Future<void> clearProposedOrders() async {
    await _withSyncing(() async {
      // 1. Clear backend
      await _reorderService.clearProposedOrders();

      // 2. Patch local rawTabReports
      final patched = {
        for (final entry in state.rawTabReports.entries)
          entry.key: entry.value
              .map((r) => r.copyWith(proposedOrder: null))
              .toList(),
      };

      // 3. Apply to state
      final newState = state.copyWith(rawTabReports: patched);
      setState(newState);

      // 4. Rebuild derived views
      _applyFiltersForCurrentTab(newState);

      debugPrint('🧹 Proposed orders cleared (backend + local)');
    });

    // 🔄 5. Refresh from backend to clear remaining stale values
    await refresh();
  }

  // 🧠 Internal
  Future<void> _withSyncing(Future<void> Function() task) async {
    if (!mounted) return;
    setState(state.copyWith(isSyncing: true));
    await task();
    if (mounted) setState(state.copyWith(isSyncing: false));
  }

  void _updateState(StockReportState newState) {
    setState(newState);
  }
}
