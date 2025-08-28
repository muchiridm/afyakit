import 'dart:typed_data';
import 'package:excel/excel.dart';

import 'package:afyakit/core/inventory/models/item_type_enum.dart';
import 'package:afyakit/core/inventory/models/items/medication_item.dart';
import 'package:afyakit/core/inventory/models/items/consumable_item.dart';
import 'package:afyakit/core/inventory/models/items/equipment_item.dart';

class ImportTemplateService {
  static Uint8List generateTemplate(ItemType type) {
    final excel = Excel.createExcel();
    final sheet = excel['Template'];
    excel.delete('Sheet1'); // 🚫 Remove the auto-generated one

    final headers = _extractHeaders(type);
    sheet.appendRow(headers);

    // Optional: add one blank/example row
    sheet.appendRow(List<CellValue?>.filled(headers.length, TextCellValue('')));

    return Uint8List.fromList(excel.encode()!);
  }

  static List<CellValue?> _extractHeaders(ItemType type) {
    final keys = switch (type) {
      ItemType.medication => MedicationItem.blank().toMap().keys,
      ItemType.consumable => ConsumableItem.blank().toMap().keys,
      ItemType.equipment => EquipmentItem.blank().toMap().keys,
      ItemType.unknown => const <String>{},
    };

    return keys.map((k) => TextCellValue(k)).toList();
  }
}
