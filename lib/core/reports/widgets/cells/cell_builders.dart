import 'package:afyakit/core/inventory/extensions/item_type_x.dart';
import 'package:afyakit/core/reports/widgets/cells/build_editable_cell_widgets.dart';
import 'package:flutter/material.dart';

/// 📦 Displays static text with graceful fallback (`-`) and ellipsis
DataCell staticTextCell(String? value, double width) {
  return DataCell(
    SizedBox(
      width: width,
      child: Text(
        (value?.trim().isNotEmpty ?? false) ? value! : '-',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

/// 🔢 Displays right-aligned bold text, e.g. numeric totals
DataCell rightAlignedBoldCell(String value, double width) {
  return DataCell(
    SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    ),
  );
}

/// 📑 Displays a list of strings as comma-separated text
DataCell csvListCell({required List<String>? values, required double width}) {
  final display = (values?.isEmpty ?? true) ? '-' : values!.join(', ');
  return DataCell(
    SizedBox(
      width: width,
      child: Text(display, maxLines: 3, overflow: TextOverflow.ellipsis),
    ),
  );
}

/// ⏳ Expiry cell with custom badge logic (non-editable)
DataCell expiryCell(double width, List<DateTime> expiries) {
  return DataCell(SizedBox(width: width, child: buildExpiryCell(expiries)));
}

/// ✍️ Editable number cell (controller-driven, no direct save logic)
DataCell editableNumberCell({
  required String keyId,
  required String itemId,
  required ItemType itemType,
  required String field,
  required int currentValue,
  required double width,
  required bool enabled,
}) {
  return DataCell(
    SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.center,
        child: buildNumberCell(
          keyId: keyId,
          itemId: itemId,
          itemType: itemType,
          field: field,
          initialValue: currentValue.toString(),
          enabled: enabled,
        ),
      ),
    ),
  );
}

/// ✍️ Editable text cell (controller-driven, no direct save logic)
DataCell editableTextCell({
  required String keyId,
  required String itemId,
  required ItemType itemType,
  required String field,
  required String currentValue,
  required double width,
  required bool enabled,
}) {
  return DataCell(
    SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerLeft,
        child: buildTextCell(
          keyId: keyId,
          itemId: itemId,
          itemType: itemType,
          field: field,
          initialValue: currentValue,
          enabled: enabled,
        ),
      ),
    ),
  );
}
