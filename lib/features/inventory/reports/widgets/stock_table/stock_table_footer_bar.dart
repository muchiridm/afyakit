import 'package:afyakit/features/inventory/reports/controllers/stock_report_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/inventory/reports/extensions/stock_order_filter_enum.dart';
import 'package:afyakit/features/inventory/reports/extensions/stock_view_mode_enum.dart';
import 'package:afyakit/features/inventory/items/extensions/item_type_x.dart';

// 👇 wrappers that expose plain List<InventoryLocation>
import 'package:afyakit/features/inventory/locations/inventory_location_controller.dart'
    show allStoresProvider, allDispensariesProvider;

// 👇 shared resolver util
import 'package:afyakit/shared/utils/resolvers/resolve_location_name.dart';

// 👇 single source of truth for what’s visible
import 'package:afyakit/features/inventory/reports/providers/visible_reports_provider.dart';

class StockTableFooterBar extends ConsumerWidget {
  final StockReportState state;
  final VoidCallback onExportPressed;
  final VoidCallback? onSaveOrderPressed;
  final VoidCallback? onClearOrderPressed;

  const StockTableFooterBar({
    super.key,
    required this.state,
    required this.onExportPressed,
    this.onSaveOrderPressed,
    this.onClearOrderPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ counts/qty from exactly the same rows the table/export use
    final summary = ref.watch(visibleSummaryProvider);
    final itemCount = summary.itemCount;
    final totalQuantity = summary.totalQty;

    final isReorderView = state.viewMode == StockViewMode.reorder;
    final isProposedFilterActive =
        state.filter == StockOrderFilter.proposedOnly;
    final showReorderButtons = isReorderView && isProposedFilterActive;

    final itemTypeLabel = switch (state.currentTabType) {
      ItemType.medication => 'Medications',
      ItemType.consumable => 'Consumables',
      ItemType.equipment => 'Equipment',
      _ => 'Items',
    };

    final exportLabel = switch (state.viewMode) {
      StockViewMode.skuOnly => 'Export SKUs',
      StockViewMode.groupedPerStore => 'Export Per Store',
      StockViewMode.groupedPerSku => 'Export Per SKU',
      StockViewMode.reorder => 'Export Order',
    };

    // 🔎 Resolve store IDs -> names for the filter chip
    final stores = ref.watch(allStoresProvider);
    final dispensaries = ref.watch(allDispensariesProvider);
    final selectedStores = state.selectedStores.toList();
    final allStoresSelected = selectedStores.isEmpty;
    final storeLabel = allStoresSelected
        ? 'All Stores'
        : selectedStores
              .map((id) => resolveLocationName(id, stores, dispensaries))
              .join(', ');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;

        final summaryRow = _buildSummary(
          itemCount: itemCount,
          totalQuantity: totalQuantity,
          itemTypeLabel: itemTypeLabel,
          storeLabel: storeLabel,
        );

        final buttons = _buildButtons(exportLabel, showReorderButtons);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey.shade100,
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [summaryRow, const SizedBox(height: 12), buttons],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [summaryRow, buttons],
                ),
        );
      },
    );
  }

  Widget _buildSummary({
    required int itemCount,
    required int totalQuantity,
    required String itemTypeLabel,
    required String storeLabel,
  }) {
    return Row(
      children: [
        Icon(Icons.medical_services, color: Colors.teal.shade700, size: 20),
        _gap(),
        Text(
          '$itemCount $itemTypeLabel',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        _gap(w: 16),
        Icon(Icons.numbers, color: Colors.green.shade800, size: 20),
        _gap(),
        Text(
          'Qty: $totalQuantity',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        _gap(w: 16),
        Icon(Icons.location_on_outlined, size: 20, color: Colors.grey.shade700),
        _gap(),
        Text(storeLabel, style: const TextStyle(fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildButtons(String exportLabel, bool showReorderButtons) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        if (showReorderButtons && onSaveOrderPressed != null)
          _styledButton(
            icon: Icons.save,
            label: 'Save Order',
            backgroundColor: Colors.lightBlue,
            onPressed: onSaveOrderPressed!,
          ),
        if (showReorderButtons && onClearOrderPressed != null)
          _styledButton(
            icon: Icons.delete,
            label: 'Clear Order',
            backgroundColor: Colors.red,
            onPressed: onClearOrderPressed!,
          ),
        _styledButton(
          icon: Icons.download,
          label: exportLabel,
          backgroundColor: Colors.teal,
          onPressed: onExportPressed,
        ),
      ],
    );
  }

  Widget _styledButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onPressed,
    Color foregroundColor = Colors.white,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _gap({double w = 8}) => SizedBox(width: w);
}
