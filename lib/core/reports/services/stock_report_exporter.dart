// lib/features/reports/services/stock_report_exporter.dart
import 'dart:io' as io show File;
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

import 'package:afyakit/core/reports/models/stock_report.dart';
import 'package:afyakit/core/inventory/models/item_type_enum.dart';
import 'package:afyakit/core/reports/extensions/stock_view_mode_enum.dart';

// 👇 use the shared resolver util exactly as provided
import 'package:afyakit/shared/utils/resolvers/resolve_location_name.dart';
import 'package:afyakit/core/inventory_locations/inventory_location.dart';

class StockReportExporter {
  /// Export ONLY the list you pass in. Make sure you pass the already-filtered
  /// reports that match what the user is currently viewing.
  static Future<void> export({
    required BuildContext context,
    required List<StockReport> reports, // ← pass filtered list
    required ItemType itemType,
    required StockViewMode viewMode,
    // 👇 lists used by resolveLocationName(...) to map id → name
    required List<InventoryLocation> stores,
    required List<InventoryLocation> dispensaries,
  }) async {
    if (reports.isEmpty) {
      _notify(context, 'No data to export.');
      return;
    }

    final isMed = itemType == ItemType.medication;
    final sheetName = '${itemType.name}_${viewMode.name}';
    final fileName = _generateFileName(itemType, viewMode);
    final excel = Excel.createExcel();
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    // ─── Headers ─────────────────────────────────────
    final headers = <String>[
      'Group',
      'Generic',
      'Brand',
      if (isMed) 'Strength' else 'Description',
      'Size',
      if (isMed) 'Route',
      if (isMed) 'Formulation',
      'Pack',
      if (!isMed) 'Unit',
      if (viewMode == StockViewMode.groupedPerStore) 'Store', // resolved name
      if (viewMode != StockViewMode.skuOnly) 'Stores', // resolved names
      'Qty',
      'Expiry',
      'Reorder',
      'Proposed',
    ];
    sheet.appendRow(headers.map(TextCellValue.new).toList());

    // ─── Data Rows ───────────────────────────────────
    final sorted = [...reports]
      ..sort((a, b) {
        final groupCompare = a.group.compareTo(b.group);
        return groupCompare != 0 ? groupCompare : a.name.compareTo(b.name);
      });

    for (final r in sorted) {
      final expiryFormatted = (r.expiryDates ?? [])
          .map((e) => '${e.year}-${e.month.toString().padLeft(2, '0')}')
          .join(', ');

      // ✅ Resolve storeId → storeName using your shared util
      final resolvedStoreName =
          (viewMode == StockViewMode.groupedPerStore && (r.storeId.isNotEmpty))
          ? resolveLocationName(r.storeId, stores, dispensaries)
          : '';

      final resolvedStoresStr = (r.stores ?? const <String>[])
          .where((id) => id.isNotEmpty)
          .map((id) => resolveLocationName(id, stores, dispensaries))
          .join(', ');

      final row = <dynamic>[
        r.group,
        r.name,
        r.brandName ?? '',
        isMed ? r.strength ?? '' : r.description ?? '',
        r.size ?? '',
        if (isMed) r.route?.join(', ') ?? '',
        if (isMed) r.formulation ?? '',
        r.packSize ?? '',
        if (!isMed) r.unit ?? '',
        if (viewMode == StockViewMode.groupedPerStore) resolvedStoreName, // ✅
        if (viewMode != StockViewMode.skuOnly) resolvedStoresStr, // ✅
        r.quantity,
        expiryFormatted,
        r.reorderLevel ?? '',
        r.proposedOrder ?? '',
      ];

      sheet.appendRow(
        row
            .map((v) => v is int ? IntCellValue(v) : TextCellValue('$v'))
            .toList(),
      );
    }

    // ─── Save to file ────────────────────────────────
    final bytes = excel.encode();
    if (bytes == null) {
      _notify(context, 'Failed to generate Excel file.');
      return;
    }

    await _saveFile(context, fileName, bytes);
  }

  static String _generateFileName(ItemType type, StockViewMode mode) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return '${type.name}_${mode.name}_$dateStr.xlsx';
  }

  static Future<void> _saveFile(
    BuildContext context,
    String fileName,
    List<int> bytes,
  ) async {
    if (kIsWeb) {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = io.File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        _notify(context, 'Exported to: ${file.path}');
      } catch (e) {
        _notify(context, 'Export failed: $e');
      }
    }
  }

  static void _notify(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
