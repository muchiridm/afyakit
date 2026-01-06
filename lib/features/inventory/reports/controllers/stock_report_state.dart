import 'package:flutter/foundation.dart';
import 'package:afyakit/features/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/features/inventory/reports/models/stock_report.dart';

import 'package:afyakit/features/inventory/reports/extensions/stock_view_mode_enum.dart';
import 'package:afyakit/features/inventory/reports/extensions/stock_order_filter_enum.dart';
import 'package:afyakit/features/inventory/reports/extensions/stock_expiry_filter_option_enum.dart';
import 'package:afyakit/features/inventory/reports/extensions/stock_availability_filter_enum.dart';

enum StockSortColumn { group, name }

@immutable
class StockReportState {
  // 🔍 Filters + UI
  final Set<String> selectedStores;
  final ExpiryFilterOption expiryFilter;
  final String searchQuery;
  final bool includeNoBatchItems;
  final StockAvailabilityFilter stockAvailabilityFilter;

  // 🧭 View config
  final StockViewMode viewMode;
  final StockOrderFilter filter;
  final bool didInitStores;

  // 📑 Tab state
  final int tabIndex;
  final Set<ItemType> loadedTabs;
  final Map<ItemType, bool> tabLoading;

  // 🔢 Sorting (compound sort stack)
  final List<(StockSortColumn column, bool ascending)> sortStack;

  // 📦 Data (single source of truth)
  final Map<ItemType, List<StockReport>> rawTabReports;

  // 🔍 Derived views
  final Map<ItemType, List<StockReport>> filteredTabReports;
  final Map<ItemType, List<StockReport>> groupedPerStoreReports;
  final Map<ItemType, List<StockReport>> groupedPerSkuReports;

  // 🕗 Pending local-only updates before sync
  final Map<ItemType, Map<String, Map<String, dynamic>>> pendingUpdates;

  // 🔄 Syncing
  final bool isSyncing;

  const StockReportState({
    required this.selectedStores,
    required this.expiryFilter,
    required this.searchQuery,
    required this.includeNoBatchItems,
    required this.stockAvailabilityFilter,
    required this.viewMode,
    required this.filter,
    required this.didInitStores,
    required this.tabIndex,
    required this.loadedTabs,
    required this.tabLoading,
    required this.sortStack,
    required this.rawTabReports,
    required this.filteredTabReports,
    required this.groupedPerStoreReports,
    required this.groupedPerSkuReports,
    required this.pendingUpdates,
    this.isSyncing = false,
  });

  /// 🧼 Initial state
  factory StockReportState.initial() => const StockReportState(
    selectedStores: {},
    expiryFilter: ExpiryFilterOption.none,
    searchQuery: '',
    includeNoBatchItems: true,
    stockAvailabilityFilter: StockAvailabilityFilter.all,
    viewMode: StockViewMode.skuOnly,
    filter: StockOrderFilter.none,
    didInitStores: false,
    tabIndex: 0,
    loadedTabs: {},
    tabLoading: {},
    sortStack: [(StockSortColumn.group, true), (StockSortColumn.name, true)],
    rawTabReports: {},
    filteredTabReports: {},
    groupedPerStoreReports: {},
    groupedPerSkuReports: {},
    pendingUpdates: {},
  );

  /// 🔄 Reset filters only
  StockReportState resetFilters() => copyWith(
    selectedStores: {},
    expiryFilter: ExpiryFilterOption.none,
    searchQuery: '',
    filter: StockOrderFilter.none,
    stockAvailabilityFilter: StockAvailabilityFilter.all,
  );

  /// 🪞 CopyWith
  StockReportState copyWith({
    Set<String>? selectedStores,
    ExpiryFilterOption? expiryFilter,
    String? searchQuery,
    bool? includeNoBatchItems,
    StockAvailabilityFilter? stockAvailabilityFilter,
    StockViewMode? viewMode,
    StockOrderFilter? filter,
    bool? didInitStores,
    int? tabIndex,
    Set<ItemType>? loadedTabs,
    Map<ItemType, bool>? tabLoading,
    List<(StockSortColumn column, bool ascending)>? sortStack,
    Map<ItemType, List<StockReport>>? rawTabReports,
    Map<ItemType, List<StockReport>>? filteredTabReports,
    Map<ItemType, List<StockReport>>? groupedPerStoreReports,
    Map<ItemType, List<StockReport>>? groupedPerSkuReports,
    Map<ItemType, Map<String, Map<String, dynamic>>>? pendingUpdates,
    bool? isSyncing,
  }) {
    return StockReportState(
      selectedStores: selectedStores ?? this.selectedStores,
      expiryFilter: expiryFilter ?? this.expiryFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      includeNoBatchItems: includeNoBatchItems ?? this.includeNoBatchItems,
      stockAvailabilityFilter:
          stockAvailabilityFilter ?? this.stockAvailabilityFilter,
      viewMode: viewMode ?? this.viewMode,
      filter: filter ?? this.filter,
      didInitStores: didInitStores ?? this.didInitStores,
      tabIndex: tabIndex ?? this.tabIndex,
      loadedTabs: loadedTabs ?? this.loadedTabs,
      tabLoading: tabLoading ?? this.tabLoading,
      sortStack: sortStack ?? this.sortStack,
      rawTabReports: rawTabReports ?? this.rawTabReports,
      filteredTabReports: filteredTabReports ?? this.filteredTabReports,
      groupedPerStoreReports:
          groupedPerStoreReports ?? this.groupedPerStoreReports,
      groupedPerSkuReports: groupedPerSkuReports ?? this.groupedPerSkuReports,
      pendingUpdates: pendingUpdates ?? this.pendingUpdates,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  // 🚨 Determines the current active tab as ItemType
  ItemType get currentTabType {
    final keys = ItemType.values.where((e) => e != ItemType.unknown).toList();
    if (tabIndex < 0 || tabIndex >= keys.length) return ItemType.unknown;
    return keys[tabIndex];
  }

  // ✅ Checks if the current tab has finished loading and is ready
  bool get reportReady {
    final current = currentTabType;
    final loading = tabLoading[current] ?? true;
    return loadedTabs.contains(current) && !loading && !isSyncing;
  }

  /// 📄 Retrieves filtered records for the current tab
  List<StockReport> get filteredTabRecords =>
      filteredTabReports[currentTabType] ?? [];

  /// 📄 Retrieves grouped records for the current tab
  List<StockReport> get filteredGroupedRecords {
    return switch (viewMode) {
      StockViewMode.groupedPerStore =>
        groupedPerStoreReports[currentTabType] ?? [],
      StockViewMode.groupedPerSku ||
      StockViewMode.reorder => groupedPerSkuReports[currentTabType] ?? [],
      _ => [],
    };
  }

  /// 📄 Retrieves all raw reports for the current tab
  List<StockReport> get currentFilteredReports {
    return switch (viewMode) {
      StockViewMode.skuOnly => filteredTabRecords,
      StockViewMode.groupedPerStore ||
      StockViewMode.groupedPerSku ||
      StockViewMode.reorder => filteredGroupedRecords,
    };
  }

  /// 📊 Returns item count and total quantity for current mode
  ({int itemCount, int totalQuantity}) getCurrentSummary() {
    // Single source of truth = exactly what the table is showing
    final rows = currentFilteredReports;

    final itemCount = rows.length;
    final totalQuantity = rows.fold<int>(0, (sum, r) => sum + (r.quantity));

    return (itemCount: itemCount, totalQuantity: totalQuantity);
  }
}
