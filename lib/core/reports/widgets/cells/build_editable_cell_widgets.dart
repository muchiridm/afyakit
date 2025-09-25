import 'package:afyakit/core/reports/widgets/cells/reactive_cell_field.dart';
import 'package:flutter/material.dart';
import 'package:afyakit/core/inventory/extensions/item_type_x.dart';

/// 📝 Builds a reactive editable text cell
Widget buildTextCell({
  required String keyId,
  required String itemId,
  required ItemType itemType,
  required String field,
  required String initialValue,
  required bool enabled,
}) {
  return ReactiveCellField(
    keyId: keyId,
    itemId: itemId,
    itemType: itemType,
    field: field,
    initialValue: initialValue,
    enabled: enabled,
    keyboardType: TextInputType.text,
    textAlign: TextAlign.left,
  );
}

/// 🔢 Builds a reactive editable number cell
Widget buildNumberCell({
  required String keyId,
  required String itemId,
  required ItemType itemType,
  required String field,
  required String initialValue,
  required bool enabled,
}) {
  return ReactiveCellField(
    keyId: keyId,
    itemId: itemId,
    itemType: itemType,
    field: field,
    initialValue: initialValue,
    enabled: enabled,
    keyboardType: TextInputType.number,
    textAlign: TextAlign.right,
  );
}

/// 🧪 Builds an expiry date badge list.
Widget buildExpiryCell(List<DateTime> dates) {
  if (dates.isEmpty) return const Text('-');

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return Wrap(
    spacing: 6,
    children: dates.map((d) {
      final expired = d.isBefore(today);
      final formatted = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      return Text(
        formatted,
        style: TextStyle(
          color: expired ? Colors.red : Colors.black,
          fontWeight: expired ? FontWeight.bold : FontWeight.normal,
        ),
      );
    }).toList(),
  );
}
