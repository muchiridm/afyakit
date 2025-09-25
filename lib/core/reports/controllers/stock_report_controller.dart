// 📦 Dependencies

import 'package:afyakit/core/auth_users/providers/auth_session/current_user_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/inventory/extensions/item_type_x.dart';
import 'package:afyakit/core/reports/extensions/stock_view_mode_enum.dart';
import 'package:afyakit/core/reports/extensions/stock_order_filter_enum.dart';
import 'package:afyakit/core/reports/extensions/stock_expiry_filter_option_enum.dart';
import 'package:afyakit/core/reports/extensions/stock_availability_filter_enum.dart';

import 'package:afyakit/core/reports/controllers/stock_report_engine.dart';
import 'package:afyakit/core/reports/controllers/stock_report_state.dart';
import 'package:afyakit/core/reports/models/stock_report.dart';
import 'package:afyakit/core/reports/models/view_models/stock_table_column.dart';
import 'package:afyakit/core/reports/models/view_models/stock_table_schema.dart';
import 'package:afyakit/core/reports/services/stock_table_filter.dart';

// 📡 Provider
final stockReportControllerProvider =
    Provider.autoDispose<StockReportController>((ref) {
      // 👇 This ensures the controller rebuilds whenever state changes
      final _ = ref.watch(stockReportEngineProvider);
      final engine = ref.watch(stockReportEngineProvider.notifier);

      return StockReportController(reportEngine: engine, ref: ref);
    });

class StockReportController {
  final StockReportEngine reportEngine;
  final Ref ref;

  StockReportController({required this.reportEngine, required this.ref});

  // 📊 Accessors
  StockReportState get state => reportEngine.publicState;
  List<ItemType> get validTabs => reportEngine.validTabs;
  StockViewMode get viewMode =>
      ref.watch(stockReportEngineProvider.select((s) => s.viewMode));

  List<StockReport> get visibleRecords {
    final tab = state.currentTabType;

    if (viewMode == StockViewMode.skuOnly ||
        viewMode == StockViewMode.reorder) {
      return state.filteredTabRecords;
    }

    if (viewMode == StockViewMode.groupedPerSku) {
      final raw = state.groupedPerSkuReports[tab] ?? [];
      return StockTableFilter.apply(
        reports: raw,
        state: state,
        overrideType: tab,
      );
    }

    if (viewMode == StockViewMode.groupedPerStore) {
      final raw = state.groupedPerStoreReports[tab] ?? [];
      return StockTableFilter.apply(
        reports: raw,
        state: state,
        overrideType: tab,
      );
    }

    // Fallback (just in case)
    return state.filteredTabRecords;
  }

  // 🔄 State Update
  void _updateState(StockReportState next) => reportEngine.setState(next);

  // 🧹 Apply filters using engine
  void applyFiltersToCurrentView() => reportEngine.applyFiltersToCurrentView();

  // 🧹 Rebuild grouped filters using engine
  void rebuildGroupedFilters() {
    reportEngine.rebuildGroupedFilters();
  }

  void _updateWith<T>(
    T value,
    StockReportState Function(StockReportState, T) updater,
  ) {
    StockTableFilter.updateAndApply(
      value: value,
      currentState: state,
      update: updater,
      setState: _updateState,
      applyFilters: (_) => applyFiltersToCurrentView(), // ✅ delegated
      applyGroupedFilters: rebuildGroupedFilters, // ✅ delegated
    );
  }

  // 🎛️ Filters & Sorting
  void setSelectedStores(Set<String> stores) =>
      _updateWith(stores, (s, v) => s.copyWith(selectedStores: v));
  void setExpiryFilter(ExpiryFilterOption filter) =>
      _updateWith(filter, (s, v) => s.copyWith(expiryFilter: v));
  void setStockAvailabilityFilter(StockAvailabilityFilter f) =>
      _updateWith(f, (s, v) => s.copyWith(stockAvailabilityFilter: v));
  void setStockFilter(StockOrderFilter f) =>
      _updateWith(f, (s, v) => s.copyWith(filter: v));

  void setSortColumn(StockSortColumn column) {
    _updateWith<List<(StockSortColumn, bool)>>(
      [(column, true)], // default ascending if not found
      (s, _) {
        final stack = List.of(s.sortStack);
        final index = stack.indexWhere((e) => e.$1 == column);

        if (index >= 0) {
          final current = stack.removeAt(index);
          // Toggle direction and move to top
          stack.insert(0, (current.$1, !current.$2));
        } else {
          // Add as new primary sort
          stack.insert(0, (column, true));
        }

        return s.copyWith(sortStack: stack);
      },
    );
  }

  void setSortColumnIndexAndDirection(int index, bool ascending) {
    final column = StockSortColumn.values[index];
    final currentStack = List.of(state.sortStack);

    // Remove if exists, to re-insert at top
    currentStack.removeWhere((e) => e.$1 == column);
    currentStack.insert(0, (column, ascending)); // promote to primary

    _updateState(state.copyWith(sortStack: currentStack));
    reportEngine.applyFiltersToCurrentView();
  }

  void toggleSortColumn(StockSortColumn column, bool ascending) {
    final oldStack = List.of(state.sortStack);

    // Remove the column if it already exists (to avoid duplicates)
    oldStack.removeWhere((e) => e.$1 == column);

    // Insert as highest priority (front of list)
    oldStack.insert(0, (column, ascending));

    _updateState(state.copyWith(sortStack: oldStack));
    reportEngine.applyFiltersToCurrentView();
  }

  // 🔁 View Actions
  void setTab(int index) => reportEngine.setTab(index);
  void setViewMode(StockViewMode mode) => reportEngine.setViewMode(mode);
  void setSearchQuery(String query) => reportEngine.setSearchQuery(query);

  // 🔄 Refresh + Sync
  Future<void> refresh() async {
    await reportEngine.refresh();
  }

  Future<void> flushPendingUpdates() async {
    await reportEngine.flushPendingUpdates();
  }

  // 📤 Export (Fixed)
  Future<void> exportReport(BuildContext context) async {
    await ref.read(stockReportEngineProvider.notifier).exportReport(context);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📤 Report exported successfully')),
      );
    }
  }

  Future<void> saveProposedOrder(BuildContext context, WidgetRef ref) async {
    final user = await ref.read(currentUserFutureProvider.future);

    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Cannot determine user identity')),
        );
      }
      return;
    }

    await reportEngine.saveProposedOrders(
      exportedByUid: user.uid,
      exportedByName: user.displayName.isNotEmpty
          ? user.displayName
          : 'Unknown',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Proposed order saved')));
    }
  }

  Future<void> clearProposedOrder(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Proposed Orders'),
        content: const Text(
          'Are you sure you want to clear all proposed order values?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await reportEngine.clearProposedOrders(); // 🔁 Delegate logic
    await refresh(); // 🔄 Refresh derived state (filters, tabs, etc.)

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🧹 Proposed orders cleared')),
      );
    }
  }

  // 🧱 Table Schema
  List<StockTableColumn> getTableSchema(StockReportState s) {
    return StockTableSchema.forItem(
      itemType: s.currentTabType,
      viewMode: s.viewMode,
    );
  }

  void handleCellSubmit({
    required BuildContext context,
    required String key, // same as itemId + field
    required String itemId,
    required ItemType itemType,
    required String field,
    required String newValue,
  }) {
    final trimmed = newValue.trim();
    if (trimmed.isEmpty) return;

    reportEngine.updateSkuField(
      itemId: itemId,
      type: itemType,
      field: field,
      newValue: trimmed,
    );

    SnackBar snack = SnackBar(content: Text('✏️ "$field" updated locally'));
    ScaffoldMessenger.of(context).showSnackBar(snack);
    debugPrint('✅ [$field] "$trimmed" for $itemId [$itemType]');
  }
}
