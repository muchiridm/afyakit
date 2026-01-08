import 'package:afyakit/features/inventory/reports/controllers/stock_report_controller.dart';
import 'package:afyakit/features/inventory/reports/controllers/stock_report_engine.dart';
import 'package:afyakit/features/inventory/reports/controllers/stock_report_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/inventory/locations/inventory_location.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_controller.dart';
import 'package:afyakit/features/inventory/reports/extensions/stock_view_mode_enum.dart';
import 'package:afyakit/features/inventory/reports/extensions/stock_order_filter_enum.dart';

import 'package:afyakit/features/inventory/reports/widgets/filters/stock_filter_bar.dart';
import 'package:afyakit/features/inventory/reports/widgets/stock_table/stock_report_header.dart';
import 'package:afyakit/features/inventory/reports/widgets/stock_table/stock_table.dart';
import 'package:afyakit/features/inventory/reports/widgets/stock_table/stock_table_footer_bar.dart';
import 'package:afyakit/features/inventory/reports/widgets/stock_table/stock_report_tabs.dart';

import 'package:afyakit/shared/widgets/base_screen.dart';

class StockReportScreen extends ConsumerStatefulWidget {
  const StockReportScreen({super.key, this.showToggleViewButton = false});
  final bool showToggleViewButton;

  @override
  ConsumerState<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends ConsumerState<StockReportScreen>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final state = ref.watch(stockReportEngineProvider);
    final controller = ref.read(stockReportControllerProvider);
    final stores = ref.watch(allStoresProvider);

    return DefaultTabController(
      length: controller.validTabs.length,
      initialIndex: state.tabIndex,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);
          tabController.addListener(() {
            if (!tabController.indexIsChanging) {
              controller.setTab(tabController.index);
            }
          });

          return BaseScreen(
            scrollable: false,
            constrainHeader: true,
            constrainBody: false,
            constrainFooter: false,
            body: _buildBody(controller, stores),
            footer: _buildFooter(state, controller, context),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    StockReportController controller,
    List<InventoryLocation> stores,
  ) {
    return Column(
      children: [
        const StockReportHeaderBar(title: 'Stock Report', showBack: true),
        StockFilterBar(
          allStores: stores,
          disabled: false,
          searchBar: _buildSearchField(controller),
        ),
        StockReportTabs(
          key: ValueKey(controller.state.tabIndex),
          tabs: controller.validTabs,
          onTabChanged: controller.setTab,
        ),
        const Divider(height: 1),
        Expanded(
          child: StockTable(
            scrollController: _scrollController,
            allStores: stores,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(StockReportController controller) {
    return TextField(
      controller: _searchController,
      onChanged: controller.setSearchQuery,
      decoration: const InputDecoration(
        hintText: 'Search stock...',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildFooter(
    StockReportState state,
    StockReportController controller,
    BuildContext context,
  ) {
    final isToggleableView =
        widget.showToggleViewButton &&
        (state.viewMode == StockViewMode.skuOnly ||
            state.viewMode == StockViewMode.groupedPerStore);

    final isReorderView = state.viewMode == StockViewMode.reorder;
    final isProposedOnly = state.filter == StockOrderFilter.proposedOnly;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        StockTableFooterBar(
          state: state,
          onExportPressed: () => controller.exportReport(context),
          onSaveOrderPressed: isReorderView && isProposedOnly
              ? () => controller.saveProposedOrder(context, ref)
              : null,
          onClearOrderPressed: isReorderView && isProposedOnly
              ? () => controller.clearProposedOrder(context)
              : null,
        ),
        if (isToggleableView)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Center(
              child: TextButton.icon(
                icon: const Icon(Icons.swap_horiz),
                label: Text(
                  state.viewMode == StockViewMode.groupedPerStore
                      ? 'SKU Only View'
                      : 'Per Store View',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                onPressed: () {
                  final next = state.viewMode == StockViewMode.skuOnly
                      ? StockViewMode.groupedPerStore
                      : StockViewMode.skuOnly;
                  controller.setViewMode(next);
                },
              ),
            ),
          ),
      ],
    );
  }
}
