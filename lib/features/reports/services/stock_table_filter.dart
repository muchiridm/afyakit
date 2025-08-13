// ✅ REFINED: StockFilterService

import 'package:afyakit/features/inventory/models/item_type_enum.dart';
import 'package:afyakit/features/reports/extensions/stock_availability_filter_enum.dart';
import 'package:afyakit/features/reports/extensions/stock_order_filter_enum.dart';
import 'package:afyakit/features/reports/extensions/stock_view_mode_enum.dart';
import 'package:afyakit/features/reports/extensions/stock_expiry_filter_option_x.dart';
import 'package:afyakit/features/reports/models/stock_report.dart';
import 'package:afyakit/features/reports/controllers/stock_report_state.dart';
import 'package:afyakit/features/reports/services/stock_table_sorter.dart';
import 'package:afyakit/shared/utils/normalize/normalize_string.dart';

class StockTableFilter {
  /// Applies filters to a list of reports based on current state.
  /// Optionally override itemType for scoped tab filtering.
  static List<StockReport> apply({
    required List<StockReport> reports,
    required StockReportState state,
    ItemType? overrideType,
  }) {
    final isReorder = state.viewMode == StockViewMode.reorder;
    final tabType = overrideType ?? state.currentTabType;
    final query = state.searchQuery.normalize();

    Iterable<StockReport> filtered = reports;

    // 0. Filter by item type (if set)
    if (tabType != ItemType.unknown) {
      filtered = filtered.where((r) => r.itemType == tabType);
    }

    // 1. Filter by selected stores
    if (state.selectedStores.isNotEmpty) {
      final normStores = state.selectedStores.map((s) => s.normalize()).toSet();
      filtered = filtered.where((r) {
        final storeId = r.storeId.normalize();
        final storeList = r.stores?.map((s) => s.normalize()).toSet() ?? {};

        return switch (state.viewMode) {
          StockViewMode.groupedPerStore => normStores.contains(storeId),
          StockViewMode.skuOnly ||
          StockViewMode.groupedPerSku => storeList.any(normStores.contains),
          _ => true,
        };
      });
    }

    // 2. Filter by expiry
    final supportsExpiry = {
      StockViewMode.groupedPerStore,
      StockViewMode.groupedPerSku,
      StockViewMode.reorder,
    };

    if (supportsExpiry.contains(state.viewMode)) {
      filtered = filtered.where((r) {
        final expiries = r.expiryDates ?? [];
        return expiries.isEmpty
            ? state.expiryFilter.allowsNoExpiry
            : expiries.any(state.expiryFilter.matches);
      });
    }

    // 3. Exclude no-batch items (unless allowed)
    const exemptModes = {StockViewMode.skuOnly, StockViewMode.groupedPerSku};
    if (!isReorder &&
        !state.includeNoBatchItems &&
        !exemptModes.contains(state.viewMode)) {
      filtered = filtered.where((r) => r.expiryDates?.isNotEmpty ?? false);
    }

    // 4. Filter by search query
    if (query.isNotEmpty) {
      filtered = filtered.where((r) => matchesQuery(r, query));
    }

    // 5. Filter by stock availability
    if (state.viewMode == StockViewMode.groupedPerSku) {
      // 🚫 Force exclude SKUs with no stock in Per SKU mode
      filtered = filtered.where((r) => r.quantity > 0);
    } else {
      // ✅ Apply user-selected availability filter in other modes
      final supportsStock = {
        StockViewMode.groupedPerStore,
        StockViewMode.reorder,
      };

      if (supportsStock.contains(state.viewMode)) {
        filtered = switch (state.stockAvailabilityFilter) {
          StockAvailabilityFilter.inStock => filtered.where(
            (r) => r.quantity > 0,
          ),
          StockAvailabilityFilter.outOfStock => filtered.where(
            (r) => r.quantity == 0,
          ),
          StockAvailabilityFilter.all => filtered,
        };
      }
    }

    // 6. Reorder filter
    filtered = switch (state.filter) {
      StockOrderFilter.reorderOnly => filtered.where((r) => r.isBelowReorder),
      StockOrderFilter.proposedOnly => filtered.where(
        (r) => (r.proposedOrder ?? 0) > 0,
      ),
      StockOrderFilter.none => filtered,
    };

    // 7. Sort results with compound sort stack
    filtered = StockTableSorter.sort(
      input: filtered.toList(),
      sortStack: state.sortStack,
    );

    return filtered.toList();
  }

  /// Matches a report against normalized query string
  static bool matchesQuery(StockReport r, String query) {
    return r.name.toLowerCase().contains(query) ||
        r.group.toLowerCase().contains(query) ||
        (r.brandName?.toLowerCase().contains(query) ?? false);
  }

  /// Unified update + apply helper
  static void updateAndApply<T>({
    required void Function(StockReportState) setState,
    required void Function(ItemType) applyFilters,
    required StockReportState currentState,
    required T value,
    required StockReportState Function(StockReportState, T) update,
    void Function()? applyGroupedFilters,
  }) {
    final newState = update(currentState, value);
    setState(newState);

    final mode = newState.viewMode;
    if (mode == StockViewMode.groupedPerSku || mode == StockViewMode.reorder) {
      applyGroupedFilters?.call();
    } else {
      applyFilters(newState.currentTabType);
    }
  }
}
