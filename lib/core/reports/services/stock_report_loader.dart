import 'package:afyakit/core/inventory/extensions/item_type_x.dart';
import 'package:afyakit/core/reports/controllers/stock_report_state.dart';
import 'package:afyakit/core/reports/extensions/stock_view_mode_enum.dart';
import 'package:afyakit/core/reports/extensions/stock_view_mode_x.dart';
import 'package:afyakit/core/reports/models/stock_report.dart';
import 'package:afyakit/core/reports/services/stock_table_filter.dart';
import 'package:afyakit/core/reports/services/stock_report_service.dart';

class StockReportLoader {
  final StockReportService reportService;

  const StockReportLoader(this.reportService);

  // ──────────────────────────────────────────────
  // 🚀 Main Loader
  // ──────────────────────────────────────────────

  Future<StockReportState> loadViewMode({
    required StockViewMode mode,
    required StockReportState currentState,
  }) async {
    final tabs = ItemType.values.where((e) => e != ItemType.unknown).toList();

    final base = currentState.copyWith(
      viewMode: mode,
      includeNoBatchItems: mode == StockViewMode.groupedPerStore,
      tabLoading: {for (final t in tabs) t: true},
    );

    final result = await loadTabs(mode: mode, tabs: tabs, state: base);
    final withRaw = base.copyWith(
      rawTabReports: result.raw,
      tabLoading: {for (final t in tabs) t: false},
    );

    if (mode == StockViewMode.groupedPerStore) {
      final grouped = buildPerStoreFromRaw(result.raw, withRaw);
      return withRaw.copyWith(groupedPerStoreReports: grouped);
    }

    if (mode == StockViewMode.groupedPerSku || mode == StockViewMode.reorder) {
      final grouped = buildGroupedFromRaw(result.raw, withRaw);
      return withRaw.copyWith(groupedPerSkuReports: grouped);
    }

    // Default: SKU-only view
    return withRaw.copyWith(filteredTabReports: result.filtered);
  }

  // ──────────────────────────────────────────────
  // 📦 Load Tabs
  // ──────────────────────────────────────────────

  Future<
    ({
      Map<ItemType, List<StockReport>> raw,
      Map<ItemType, List<StockReport>> filtered,
    })
  >
  loadTabs({
    required StockViewMode mode,
    required List<ItemType> tabs,
    required StockReportState state,
  }) async {
    final all = reportService.buildReports(mode: mode);

    final raw = <ItemType, List<StockReport>>{};
    final filtered = <ItemType, List<StockReport>>{};

    for (final type in tabs) {
      final tabReports = all.where((r) => r.itemType == type).toList();
      raw[type] = tabReports;

      if (!mode.isGrouped) {
        filtered[type] = StockTableFilter.apply(
          reports: tabReports,
          state: state,
          overrideType: type,
        );
      }
    }

    return (raw: raw, filtered: filtered);
  }

  // ──────────────────────────────────────────────
  // 🧮 Build Grouped by SKU (itemId)
  // ──────────────────────────────────────────────

  Map<ItemType, List<StockReport>> buildGroupedFromRaw(
    Map<ItemType, List<StockReport>> rawTabs,
    StockReportState state,
  ) {
    final grouped = <String, List<StockReport>>{};

    for (final entry in rawTabs.entries) {
      final filtered = StockTableFilter.apply(
        reports: entry.value,
        state: state,
        overrideType: entry.key,
      );
      for (final report in filtered) {
        grouped.putIfAbsent(report.itemId, () => []).add(report);
      }
    }

    // Flatten back to ItemType keys
    final byType = <ItemType, List<StockReport>>{};
    for (final r in grouped.values.expand((e) => e)) {
      byType.putIfAbsent(r.itemType, () => []).add(r);
    }
    return byType;
  }

  // ──────────────────────────────────────────────
  // 🧮 Build Per-Store (respect selectedStores)
  // ──────────────────────────────────────────────

  Map<ItemType, List<StockReport>> buildPerStoreFromRaw(
    Map<ItemType, List<StockReport>> rawTabs,
    StockReportState state,
  ) {
    final byType = <ItemType, List<StockReport>>{};
    final selected = state.selectedStores;

    bool matchesStore(StockReport r) {
      if (selected.isEmpty) return true;
      final inId = (selected.contains(r.storeId));
      final inList = (r.stores?.any(selected.contains) ?? false);
      return inId || inList;
    }

    for (final entry in rawTabs.entries) {
      // Apply your common filters first (search, expiry, stock status, etc.)
      var filtered = StockTableFilter.apply(
        reports: entry.value,
        state: state,
        overrideType: entry.key,
      );

      // Ensure the store predicate is enforced for Per Store
      filtered = filtered.where(matchesStore).toList();

      byType[entry.key] = filtered;
    }
    return byType;
  }

  // 🔁 Patch raw reports with backend updates
  Map<ItemType, List<StockReport>> patchRawReports({
    required Map<ItemType, List<StockReport>> current,
    required List<StockReport> updates,
  }) {
    final patched = Map<ItemType, List<StockReport>>.from(current);

    for (final updated in updates) {
      final type = updated.itemType;
      final list = List<StockReport>.from(patched[type] ?? []);
      final index = list.indexWhere((r) => r.id == updated.id);
      if (index != -1) {
        list[index] = updated;
      } else {
        list.add(updated);
      }
      patched[type] = list;
    }

    return patched;
  }

  // ──────────────────────────────────────────────
  // 🔍 Filters (All / Per Tab / Grouped)
  // ──────────────────────────────────────────────

  void applyFilters(
    StockReportState state, {
    required void Function(StockReportState) updateState,
  }) {
    if (state.viewMode.isGrouped) return;

    final updated = {
      for (final entry in state.rawTabReports.entries)
        entry.key: StockTableFilter.apply(
          reports: entry.value,
          state: state,
          overrideType: entry.key,
        ),
    };

    updateState(state.copyWith(filteredTabReports: updated));
  }

  void applyFiltersToTab(
    StockReportState state,
    ItemType type, {
    required void Function(StockReportState) updateState,
  }) {
    final raw = state.rawTabReports[type];
    if (raw == null) return;

    final filtered = StockTableFilter.apply(
      reports: raw,
      state: state,
      overrideType: type,
    );

    updateState(
      state.copyWith(
        filteredTabReports: {...state.filteredTabReports, type: filtered},
      ),
    );
  }

  void applyFiltersToGroupedReports({
    required StockReportState state,
    required ItemType itemType,
    required void Function(StockReportState) updateState,
  }) {
    if (state.viewMode == StockViewMode.groupedPerStore) {
      final perStore = buildPerStoreFromRaw(state.rawTabReports, state);
      updateState(state.copyWith(groupedPerStoreReports: perStore));
    } else {
      final perSku = buildGroupedFromRaw(state.rawTabReports, state);
      updateState(state.copyWith(groupedPerSkuReports: perSku));
    }
  }

  // ──────────────────────────────────────────────
  // ✏️ SKU Editable Helpers
  // ──────────────────────────────────────────────

  List<StockReport> getCurrentEditableList(
    StockReportState state,
    ItemType type,
  ) {
    if (state.viewMode.isGrouped) {
      return state.filteredGroupedRecords;
    }
    return state.filteredTabReports[type] ?? [];
  }

  StockReportState updateListInState(
    StockReportState state,
    ItemType type,
    List<StockReport> updated,
  ) {
    if (state.viewMode.isGrouped) {
      // Grouped views should not patch lists
      return state;
    }
    return state.copyWith(
      filteredTabReports: {...state.filteredTabReports, type: updated},
    );
  }
}
