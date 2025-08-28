import 'package:afyakit/core/reports/extensions/stock_report_x.dart';
import 'package:flutter/material.dart';

import 'package:afyakit/core/inventory/models/item_type_enum.dart';
import 'package:afyakit/core/inventory_locations/inventory_location.dart';
import 'package:afyakit/core/reports/extensions/stock_table_column_id_enum.dart';
import 'package:afyakit/core/reports/extensions/stock_view_mode_enum.dart';
import 'package:afyakit/core/reports/extensions/stock_view_mode_x.dart';
import 'package:afyakit/core/reports/models/stock_report.dart';
import 'package:afyakit/core/reports/models/view_models/stock_table_column.dart';
import 'package:afyakit/core/reports/widgets/cells/cell_builders.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_location_name.dart';

typedef SortCallback = void Function(int columnIndex, bool ascending);

const kHeaderStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontSize: 14,
  color: Colors.teal,
);

List<DataColumn> buildStockTableColumns({
  required List<StockTableColumn> schema,
  required SortCallback onSort,
  required int sortColumnIndex,
  required bool sortAscending,
}) {
  return schema.asMap().entries.map((entry) {
    final index = entry.key;
    final col = entry.value;

    // 👇 Determine if the column is numeric based on its ID
    final isNumeric = [
      StockTableColumnId.qty,
      StockTableColumnId.reorder,
      StockTableColumnId.proposed,
    ].contains(col.id);

    return DataColumn(
      label: SizedBox(
        width: col.width,
        child: Align(
          alignment: isNumeric ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            col.label,
            style: kHeaderStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      onSort: col.sortable
          ? (int _, bool ascending) => onSort(index, ascending)
          : null,
    );
  }).toList();
}

DataRow buildStockTableRow({
  required StockReport report,
  required StockViewMode viewMode,
  required List<InventoryLocation> stores,
  required List<StockTableColumn> schema,
}) {
  final itemType = report.itemType;

  return DataRow(
    key: ValueKey(report.generateStableRowKey(viewMode)),

    cells: schema.map((col) {
      return _buildCellFromColumnId(
        col.id,
        width: col.width,
        report: report,
        itemType: itemType,
        viewMode: viewMode,
        stores: stores,
      );
    }).toList(),
  );
}

DataCell _buildCellFromColumnId(
  StockTableColumnId columnId, {
  required double width,
  required StockReport report,
  required ItemType itemType,
  required StockViewMode viewMode,
  required List<InventoryLocation> stores,
}) {
  final editable = viewMode.editableColumns.contains(columnId);
  final itemId = report.itemId;

  switch (columnId) {
    case StockTableColumnId.group:
      return staticTextCell(report.group, width);

    case StockTableColumnId.name:
      return staticTextCell(report.name, width);

    case StockTableColumnId.brand:
      return staticTextCell(report.brandName, width);

    case StockTableColumnId.description:
      return staticTextCell(report.description, width);

    case StockTableColumnId.strength:
      return staticTextCell(report.strength, width);

    case StockTableColumnId.size:
      return staticTextCell(report.size, width);

    case StockTableColumnId.route:
      return csvListCell(values: report.route, width: width);

    case StockTableColumnId.formulation:
      return staticTextCell(report.formulation, width);

    case StockTableColumnId.pack:
      return editableTextCell(
        keyId: '$itemId|packSize',
        itemId: itemId,
        itemType: itemType,
        field: 'packSize',
        currentValue: report.packSize ?? '',
        width: width,
        enabled: editable,
      );

    case StockTableColumnId.unit:
      return staticTextCell(report.unit, width);

    case StockTableColumnId.package:
      return editableTextCell(
        keyId: '$itemId|package',
        itemId: itemId,
        itemType: itemType,
        field: 'package',
        currentValue: report.package ?? '',
        width: width,
        enabled: editable,
      );

    case StockTableColumnId.model:
      return staticTextCell(report.model, width);

    case StockTableColumnId.manufacturer:
      return staticTextCell(report.manufacturer, width);

    case StockTableColumnId.serialNumber:
      return staticTextCell(report.serialNumber, width);

    case StockTableColumnId.store:
      final name = resolveLocationName(report.storeId, stores, []);
      return staticTextCell(name, width);

    case StockTableColumnId.reorder:
      return editableNumberCell(
        keyId: '$itemId|reorderLevel',
        itemId: itemId,
        itemType: itemType,
        field: 'reorderLevel',
        currentValue: report.reorderLevel ?? 0,
        width: width,
        enabled: editable,
      );

    case StockTableColumnId.proposed:
      return editableNumberCell(
        keyId: '$itemId|proposedOrder',
        itemId: itemId,
        itemType: itemType,
        field: 'proposedOrder',
        currentValue: report.proposedOrder ?? 0,
        width: width,
        enabled: editable,
      );

    case StockTableColumnId.qty:
      return rightAlignedBoldCell('${report.quantity}', width);

    case StockTableColumnId.expiry:
      return expiryCell(width, report.expiryDates ?? []);

    case StockTableColumnId.stores:
      final names =
          report.stores
              ?.map((id) => resolveLocationName(id, stores, []))
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList() ??
          [];
      names.sort();
      return csvListCell(values: names, width: width);
  }
}
