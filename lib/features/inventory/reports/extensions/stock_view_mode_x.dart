import 'package:flutter/material.dart';
import 'package:afyakit/features/inventory/reports/extensions/stock_table_column_id_enum.dart';
import 'package:afyakit/features/inventory/reports/extensions/stock_view_mode_enum.dart';

extension StockViewModeX on StockViewMode {
  // ────────────────────────────────────────
  // 🧱 Column Configuration
  // ────────────────────────────────────────

  Set<StockTableColumnId> get visibleColumns {
    switch (this) {
      case StockViewMode.skuOnly:
        return {
          StockTableColumnId.group,
          StockTableColumnId.name,
          StockTableColumnId.brand,
          StockTableColumnId.size,
          StockTableColumnId.strength,
          StockTableColumnId.route,
          StockTableColumnId.formulation,
          StockTableColumnId.pack,
          StockTableColumnId.package,
          StockTableColumnId.unit,
          StockTableColumnId.model,
          StockTableColumnId.manufacturer,
          StockTableColumnId.serialNumber,
        };

      case StockViewMode.groupedPerStore:
        return {
          StockTableColumnId.group,
          StockTableColumnId.name,
          StockTableColumnId.brand,
          StockTableColumnId.size,
          StockTableColumnId.strength,
          StockTableColumnId.route,
          StockTableColumnId.formulation,
          StockTableColumnId.pack,
          StockTableColumnId.package,
          StockTableColumnId.unit,
          StockTableColumnId.model,
          StockTableColumnId.manufacturer,
          StockTableColumnId.serialNumber,
          StockTableColumnId.store,
          StockTableColumnId.qty,
          StockTableColumnId.expiry,
          StockTableColumnId.reorder,
          StockTableColumnId.proposed,
        };

      case StockViewMode.groupedPerSku:
      case StockViewMode.reorder:
        return {
          StockTableColumnId.group,
          StockTableColumnId.name,
          StockTableColumnId.brand,
          StockTableColumnId.size,
          StockTableColumnId.strength,
          StockTableColumnId.route,
          StockTableColumnId.formulation,
          StockTableColumnId.pack,
          StockTableColumnId.package,
          StockTableColumnId.unit,
          StockTableColumnId.model,
          StockTableColumnId.manufacturer,
          StockTableColumnId.serialNumber,
          StockTableColumnId.stores,
          StockTableColumnId.qty,
          StockTableColumnId.expiry,
          StockTableColumnId.reorder,
          StockTableColumnId.proposed,
        };
    }
  }

  Set<StockTableColumnId> get editableColumns {
    switch (this) {
      case StockViewMode.skuOnly:
        return {StockTableColumnId.pack, StockTableColumnId.package};
      case StockViewMode.reorder:
        return {
          StockTableColumnId.reorder,
          StockTableColumnId.proposed,
          StockTableColumnId.pack,
          StockTableColumnId.package,
        };
      default:
        return {};
    }
  }

  // ────────────────────────────────────────
  // 🎛️ UI Visibility Toggles
  // ────────────────────────────────────────

  bool get showStoreFilter => this == StockViewMode.groupedPerStore;

  bool get showOrderFilter =>
      this == StockViewMode.reorder || this == StockViewMode.groupedPerSku;

  bool get showFooterBar => true;

  bool get showSearchBar => true;

  bool get showExpiryFilter => switch (this) {
    StockViewMode.groupedPerStore ||
    StockViewMode.groupedPerSku ||
    StockViewMode.reorder => true,
    _ => false,
  };

  bool get showStockStatusFilter => this == StockViewMode.reorder;

  bool get showItemTypeTabs => switch (this) {
    StockViewMode.skuOnly || StockViewMode.groupedPerStore => true,
    _ => false,
  };

  // ────────────────────────────────────────
  // ⚙️ Logical Behavior Flags
  // ────────────────────────────────────────

  bool get isGrouped => switch (this) {
    StockViewMode.groupedPerStore ||
    StockViewMode.groupedPerSku ||
    StockViewMode.reorder => true,
    _ => false,
  };

  bool get isEditable => this == StockViewMode.reorder;

  bool get isFlatList => this == StockViewMode.skuOnly;

  bool get needsPreloading => switch (this) {
    StockViewMode.groupedPerSku || StockViewMode.reorder => true,
    _ => false,
  };

  // ────────────────────────────────────────
  // 🏷️ UI Labels & Icons
  // ────────────────────────────────────────

  String get label => switch (this) {
    StockViewMode.skuOnly => 'SKU-Only',
    StockViewMode.groupedPerStore => 'Grouped Per Store',
    StockViewMode.groupedPerSku => 'Grouped Per SKU',
    StockViewMode.reorder => 'Reorder View',
  };

  IconData get icon => switch (this) {
    StockViewMode.skuOnly => Icons.list,
    StockViewMode.groupedPerStore => Icons.store,
    StockViewMode.groupedPerSku => Icons.merge_type,
    StockViewMode.reorder => Icons.shopping_cart,
  };
}
