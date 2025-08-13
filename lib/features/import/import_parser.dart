import 'dart:typed_data';
import 'package:afyakit/features/inventory/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/models/items/medication_item.dart';
import 'package:afyakit/features/inventory/models/items/equipment_item.dart';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';

class ImportParser {
  static final _uuid = Uuid();

  static List<MedicationItem> parseMedications(Uint8List fileBytes) {
    final excel = Excel.decodeBytes(fileBytes);
    final List<MedicationItem> medications = [];

    for (final sheet in excel.tables.values) {
      if (sheet.rows.length < 2) continue;

      final headers = _extractHeaders(sheet.rows[0]);

      for (final row in sheet.rows.skip(1)) {
        if (_isRowEmpty(row)) continue;

        medications.add(
          MedicationItem(
            id: _uuid.v4(),
            group: _cell(row, headers['group']),
            name: _cell(row, headers['genericname']),
            brandName: _cellOptional(row, headers['brandname']),
            strength: _cellOptional(row, headers['strength']),
            size: _cellOptional(row, headers['size']),
            formulation: _cellOptional(row, headers['formulation']),
            packSize: _cellOptional(row, headers['packsize']),
            route: _cellList(row, headers['route']),
            reorderLevel: _cellIntOptional(row, headers['reorderlevel']),
            proposedOrder: _cellIntOptional(row, headers['proposedorder']),
          ),
        );
      }
    }

    return medications;
  }

  static List<ConsumableItem> parseConsumables(Uint8List fileBytes) {
    final excel = Excel.decodeBytes(fileBytes);
    final List<ConsumableItem> consumables = [];

    for (final sheet in excel.tables.values) {
      if (sheet.rows.length < 2) continue;

      final headers = _extractHeaders(sheet.rows[0]);

      for (final row in sheet.rows.skip(1)) {
        if (_isRowEmpty(row)) continue;

        consumables.add(
          ConsumableItem(
            id: _uuid.v4(),
            group: _cell(row, headers['group']),
            name: _cell(row, headers['genericname']),
            brandName: _cellOptional(row, headers['brandname']),
            description: _cellOptional(row, headers['description']),
            size: _cellOptional(row, headers['size']),
            packSize: _cellOptional(row, headers['packsize']),
            unit: _cellOptional(row, headers['unit']),
            package: _cellOptional(row, headers['package']),
            reorderLevel: _cellIntOptional(row, headers['reorderlevel']),
            proposedOrder: _cellIntOptional(row, headers['proposedorder']),
          ),
        );
      }
    }

    return consumables;
  }

  static List<EquipmentItem> parseEquipment(Uint8List fileBytes) {
    final excel = Excel.decodeBytes(fileBytes);
    final List<EquipmentItem> equipment = [];

    for (final sheet in excel.tables.values) {
      if (sheet.rows.length < 2) continue;

      final headers = _extractHeaders(sheet.rows[0]);

      for (final row in sheet.rows.skip(1)) {
        if (_isRowEmpty(row)) continue;

        equipment.add(
          EquipmentItem(
            id: _uuid.v4(),
            group: _cell(row, headers['group']),
            name: _cell(row, headers['name']),
            description: _cellOptional(row, headers['description']),
            model: _cellOptional(row, headers['model']),
            manufacturer: _cellOptional(row, headers['manufacturer']),
            serialNumber: _cellOptional(row, headers['serialnumber']),
            package: _cellOptional(row, headers['package']),
            reorderLevel: _cellIntOptional(row, headers['reorderlevel']),
            proposedOrder: _cellIntOptional(row, headers['proposedorder']),
          ),
        );
      }
    }

    return equipment;
  }

  // ───────────────────────────────────────────────────────────────
  // 🔧 Utility Methods
  // ───────────────────────────────────────────────────────────────

  static Map<String, int> _extractHeaders(List<Data?> row) {
    return {
      for (int i = 0; i < row.length; i++)
        (row[i]?.value.toString().trim().toLowerCase() ?? ''): i,
    };
  }

  static bool _isRowEmpty(List<Data?> row) {
    return row.every((cell) => cell == null || cell.value == null);
  }

  static String _cell(List<Data?> row, int? index) {
    if (index == null || index >= row.length) return '';
    final value = row[index]?.value?.toString().trim();
    return value ?? '';
  }

  static String? _cellOptional(List<Data?> row, int? index) {
    final value = _cell(row, index);
    return value.isEmpty ? null : value;
  }

  static int? _cellIntOptional(List<Data?> row, int? index) {
    final value = _cellOptional(row, index);
    if (value == null) return null;
    final parsed = int.tryParse(value);
    return parsed;
  }

  static List<String>? _cellList(List<Data?> row, int? index) {
    final text = _cellOptional(row, index);
    if (text == null) return null;
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}
