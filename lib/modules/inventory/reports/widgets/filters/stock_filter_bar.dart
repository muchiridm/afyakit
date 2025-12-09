import 'package:afyakit/modules/inventory/locations/inventory_location_type_enum.dart';
import 'package:afyakit/modules/inventory/reports/controllers/stock_report_controller.dart';
import 'package:afyakit/modules/inventory/reports/controllers/stock_report_engine.dart';
import 'package:afyakit/modules/inventory/reports/controllers/stock_report_state.dart';
import 'package:afyakit/modules/inventory/reports/extensions/stock_view_mode_x.dart';
import 'package:flutter/material.dart';
import 'package:afyakit/modules/inventory/locations/inventory_location.dart';
import 'package:afyakit/modules/inventory/reports/extensions/stock_availability_filter_enum.dart';
import 'package:afyakit/modules/inventory/reports/extensions/stock_expiry_filter_option_enum.dart';
import 'package:afyakit/modules/inventory/reports/extensions/stock_order_filter_enum.dart';
import 'package:afyakit/modules/inventory/reports/extensions/stock_view_mode_enum.dart';
import 'package:afyakit/modules/inventory/reports/widgets/filters/filter_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StockFilterBar extends ConsumerWidget {
  final List<InventoryLocation>? allStores;
  final bool disabled;
  final Widget? searchBar;

  const StockFilterBar({
    super.key,
    this.allStores,
    this.disabled = false,
    this.searchBar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockReportEngineProvider);
    final controller = ref.read(stockReportControllerProvider);
    final viewMode = state.viewMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: AbsorbPointer(
        absorbing: disabled,
        child: Opacity(
          opacity: disabled ? 0.5 : 1.0,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildLeftSection(viewMode, controller),
              _buildRightSection(ref, controller, state, viewMode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftSection(
    StockViewMode viewMode,
    StockReportController controller,
  ) {
    return Wrap(
      spacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildViewModeFilter(controller, viewMode),
        if (viewMode.showSearchBar && searchBar != null) _buildSearchBar(),
      ],
    );
  }

  Widget _buildRightSection(
    WidgetRef ref,
    StockReportController controller,
    StockReportState state,
    StockViewMode viewMode,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (viewMode.showStoreFilter)
          _buildStoreFilter(ref, controller, state.selectedStores),
        if (viewMode.showExpiryFilter)
          _buildExpiryFilter(controller, state.expiryFilter),
        if (viewMode.showStockStatusFilter)
          _buildStockStatusFilter(controller, state.stockAvailabilityFilter),
        if (viewMode.showOrderFilter)
          _buildOrderFilter(controller, state.filter),
        _buildRefreshButton(ref), // ✅ part of the Wrap — no need for Row
      ],
    );
  }

  Widget _buildViewModeFilter(
    StockReportController controller,
    StockViewMode viewMode,
  ) {
    return SizedBox(
      width: 180,
      height: 48,
      child: FilterPopup<StockViewMode>(
        label: 'View Mode',
        options: const [
          StockViewMode.skuOnly,
          StockViewMode.groupedPerStore,
          StockViewMode.groupedPerSku,
          StockViewMode.reorder,
        ],
        selected: {viewMode},
        onChanged: (val) => controller.setViewMode(val.first),
        labelBuilder: (val) => switch (val) {
          StockViewMode.skuOnly => 'SKU Only',
          StockViewMode.groupedPerStore => 'Per Store',
          StockViewMode.groupedPerSku => 'Per SKU',
          StockViewMode.reorder => 'Reorder Table',
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: SizedBox(height: 48, child: searchBar!),
    );
  }

  Widget _buildStoreFilter(
    WidgetRef ref,
    StockReportController controller,
    Set<String> selectedStores,
  ) {
    final stores = allStores ?? [];
    final options = stores.map((e) => e.id).toList();

    return SizedBox(
      width: 200,
      height: 48,
      child: FilterPopup<String>(
        label: 'Store',
        options: options,
        selected: selectedStores,
        onChanged: (ids) {
          final updated = ids.contains('ALL') ? <String>{} : ids;
          controller.setSelectedStores(updated);
        },
        allowAllOption: true,
        allOptionValue: 'ALL',
        allOptionLabel: 'All Stores',
        labelBuilder: (id) {
          final match = stores.firstWhere(
            (e) => e.id.trim().toLowerCase() == id.trim().toLowerCase(),
            orElse: () => InventoryLocation(
              id: id,
              name: id,
              tenantId: '',
              type: InventoryLocationType.store,
            ),
          );
          return match.name;
        },
      ),
    );
  }

  Widget _buildExpiryFilter(
    StockReportController controller,
    ExpiryFilterOption selected,
  ) {
    return SizedBox(
      width: 160,
      height: 48,
      child: FilterPopup<ExpiryFilterOption>(
        label: 'Expiry Filter',
        options: ExpiryFilterOption.values,
        selected: {selected},
        onChanged: (val) => controller.setExpiryFilter(val.first),
        labelBuilder: (val) => val.label,
      ),
    );
  }

  Widget _buildStockStatusFilter(
    StockReportController controller,
    StockAvailabilityFilter selected,
  ) {
    return SizedBox(
      width: 160,
      height: 48,
      child: FilterPopup<StockAvailabilityFilter>(
        label: 'Stock Status',
        options: const [
          StockAvailabilityFilter.all,
          StockAvailabilityFilter.inStock,
          StockAvailabilityFilter.outOfStock,
        ],
        selected: {selected},
        onChanged: (val) => controller.setStockAvailabilityFilter(val.first),
        labelBuilder: (val) => switch (val) {
          StockAvailabilityFilter.all => 'All',
          StockAvailabilityFilter.inStock => 'In Stock',
          StockAvailabilityFilter.outOfStock => 'Out of Stock',
        },
      ),
    );
  }

  Widget _buildOrderFilter(
    StockReportController controller,
    StockOrderFilter selected,
  ) {
    return SizedBox(
      width: 180,
      height: 48,
      child: FilterPopup<StockOrderFilter>(
        label: 'Order Filter',
        options: const [
          StockOrderFilter.none,
          StockOrderFilter.reorderOnly,
          StockOrderFilter.proposedOnly,
        ],
        selected: {selected},
        onChanged: (val) => controller.setStockFilter(val.first),
        labelBuilder: (val) => switch (val) {
          StockOrderFilter.none => 'All',
          StockOrderFilter.reorderOnly => 'Below Reorder',
          StockOrderFilter.proposedOnly => 'Proposed > 0',
        },
      ),
    );
  }

  Widget _buildRefreshButton(WidgetRef ref, {bool disabled = false}) {
    final state = ref.watch(stockReportEngineProvider);
    final controller = ref.read(stockReportControllerProvider);
    final isSyncing = state.isSyncing;
    final canPress = !isSyncing && !disabled;

    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: canPress
              ? () async {
                  debugPrint('[StockFilterBar] 🔄 Refresh pressed');
                  await controller.refresh();
                }
              : null,
          icon: isSyncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.sync),
          label: Text(isSyncing ? 'Refreshing...' : 'Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
