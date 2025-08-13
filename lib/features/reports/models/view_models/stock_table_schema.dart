import 'package:afyakit/features/inventory/models/item_type_enum.dart';
import 'package:afyakit/features/reports/extensions/stock_table_column_id_enum.dart';
import 'package:afyakit/features/reports/extensions/stock_view_mode_enum.dart';
import 'package:afyakit/features/reports/extensions/stock_view_mode_x.dart';
import 'package:afyakit/features/reports/models/view_models/stock_table_column.dart';

/// Provides the dynamic schema (columns) for the stock table
/// based on the current [StockViewMode] and [ItemType].
class StockTableSchema {
  /// Returns the final list of columns to display in the table,
  /// filtered by [viewMode] and sorted according to [itemType].
  static List<StockTableColumn> forItem({
    required ItemType itemType,
    required StockViewMode viewMode,
  }) {
    final allColumns = _buildAllColumns();
    final visibleIds = viewMode.visibleColumns.toSet();
    final allowedIds = _getAllowedColumnsForItem(itemType, visibleIds);
    final sortOrder = _columnOrderMap[itemType] ?? StockTableColumnId.values;

    // Filter and sort based on allowed + type order
    final filtered = allColumns.where((col) => allowedIds.contains(col.id));
    return filtered.toList()..sort(
      (a, b) => sortOrder.indexOf(a.id).compareTo(sortOrder.indexOf(b.id)),
    );
  }

  /// Full list of all possible table columns (master schema).
  static List<StockTableColumn> _buildAllColumns() => const [
    StockTableColumn(
      id: StockTableColumnId.group,
      label: 'Group',
      width: 90,
      sortable: true,
      sortIndex: 0,
    ),
    StockTableColumn(
      id: StockTableColumnId.name,
      label: 'Name',
      width: 180,
      sortable: true,
      sortIndex: 1,
    ),
    StockTableColumn(id: StockTableColumnId.brand, label: 'Brand', width: 140),
    StockTableColumn(
      id: StockTableColumnId.strength,
      label: 'Strength',
      width: 80,
    ),
    StockTableColumn(id: StockTableColumnId.size, label: 'Size', width: 60),
    StockTableColumn(id: StockTableColumnId.route, label: 'Route', width: 90),
    StockTableColumn(
      id: StockTableColumnId.formulation,
      label: 'Formulation',
      width: 90,
    ),
    StockTableColumn(id: StockTableColumnId.pack, label: 'Pack', width: 60),
    StockTableColumn(
      id: StockTableColumnId.description,
      label: 'Description',
      width: 120,
    ),
    StockTableColumn(id: StockTableColumnId.unit, label: 'Unit', width: 70),
    StockTableColumn(
      id: StockTableColumnId.package,
      label: 'Package',
      width: 90,
    ),
    StockTableColumn(id: StockTableColumnId.model, label: 'Model', width: 100),
    StockTableColumn(
      id: StockTableColumnId.manufacturer,
      label: 'Manufacturer',
      width: 120,
    ),
    StockTableColumn(
      id: StockTableColumnId.serialNumber,
      label: 'Serial No.',
      width: 120,
    ),
    StockTableColumn(
      id: StockTableColumnId.store,
      label: 'Store',
      width: 100,
      sortIndex: 8,
    ),
    StockTableColumn(
      id: StockTableColumnId.stores,
      label: 'Stores',
      width: 140,
    ),
    StockTableColumn(id: StockTableColumnId.qty, label: 'Qty', width: 60),
    StockTableColumn(
      id: StockTableColumnId.expiry,
      label: 'Expiry',
      width: 110,
    ),
    StockTableColumn(
      id: StockTableColumnId.reorder,
      label: 'Reorder',
      width: 70,
    ),
    StockTableColumn(
      id: StockTableColumnId.proposed,
      label: 'Proposed',
      width: 70,
    ),
  ];

  /// Map of preferred column order per item type
  static const Map<ItemType, List<StockTableColumnId>> _columnOrderMap = {
    ItemType.medication: [
      StockTableColumnId.group,
      StockTableColumnId.name,
      StockTableColumnId.brand,
      StockTableColumnId.strength,
      StockTableColumnId.size,
      StockTableColumnId.route,
      StockTableColumnId.formulation,
      StockTableColumnId.pack,
      StockTableColumnId.store,
      StockTableColumnId.stores,
      StockTableColumnId.qty,
      StockTableColumnId.expiry,
      StockTableColumnId.reorder,
      StockTableColumnId.proposed,
    ],
    ItemType.consumable: [
      StockTableColumnId.group,
      StockTableColumnId.name,
      StockTableColumnId.brand,
      StockTableColumnId.description,
      StockTableColumnId.size,
      StockTableColumnId.pack,
      StockTableColumnId.unit,
      StockTableColumnId.package,
      StockTableColumnId.store,
      StockTableColumnId.stores,
      StockTableColumnId.qty,
      StockTableColumnId.expiry,
      StockTableColumnId.reorder,
      StockTableColumnId.proposed,
    ],
    ItemType.equipment: [
      StockTableColumnId.group,
      StockTableColumnId.name,
      StockTableColumnId.brand,
      StockTableColumnId.package,
      StockTableColumnId.model,
      StockTableColumnId.manufacturer,
      StockTableColumnId.serialNumber,
      StockTableColumnId.store,
      StockTableColumnId.stores,
      StockTableColumnId.qty,
      StockTableColumnId.expiry,
      StockTableColumnId.reorder,
      StockTableColumnId.proposed,
    ],
  };

  /// Returns only the relevant column IDs for a given item type,
  /// filtered by what the current [viewMode] allows.
  static Set<StockTableColumnId> _getAllowedColumnsForItem(
    ItemType itemType,
    Set<StockTableColumnId> visibleFromView,
  ) {
    final base = switch (itemType) {
      ItemType.medication => {
        StockTableColumnId.group,
        StockTableColumnId.name,
        StockTableColumnId.brand,
        StockTableColumnId.strength,
        StockTableColumnId.size,
        StockTableColumnId.route,
        StockTableColumnId.formulation,
        StockTableColumnId.pack,
        StockTableColumnId.store,
        StockTableColumnId.stores,
        StockTableColumnId.qty,
        StockTableColumnId.expiry,
        StockTableColumnId.reorder,
        StockTableColumnId.proposed,
      },
      ItemType.consumable => {
        StockTableColumnId.group,
        StockTableColumnId.name,
        StockTableColumnId.brand,
        StockTableColumnId.description,
        StockTableColumnId.size,
        StockTableColumnId.pack,
        StockTableColumnId.unit,
        StockTableColumnId.package,
        StockTableColumnId.store,
        StockTableColumnId.stores,
        StockTableColumnId.qty,
        StockTableColumnId.expiry,
        StockTableColumnId.reorder,
        StockTableColumnId.proposed,
      },
      ItemType.equipment => {
        StockTableColumnId.group,
        StockTableColumnId.name,
        StockTableColumnId.brand,
        StockTableColumnId.package,
        StockTableColumnId.model,
        StockTableColumnId.manufacturer,
        StockTableColumnId.serialNumber,
        StockTableColumnId.store,
        StockTableColumnId.stores,
        StockTableColumnId.qty,
        StockTableColumnId.expiry,
        StockTableColumnId.reorder,
        StockTableColumnId.proposed,
      },
      ItemType.unknown => visibleFromView,
    };

    return base.intersection(visibleFromView);
  }
}
