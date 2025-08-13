import 'package:afyakit/features/inventory/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/models/items/medication_item.dart';
import 'package:afyakit/features/inventory/models/items/equipment_item.dart';

class ImportValidator {
  /// Shared helper
  static bool isBlank(String? value) => value == null || value.trim().isEmpty;

  /// ─────────────────────────────────────────────
  /// 💊 Medication Validation
  /// ─────────────────────────────────────────────
  static List<String> validateMedications(
    List<MedicationItem> meds, {
    int startRow = 2,
  }) {
    final errors = <String>[];

    for (int i = 0; i < meds.length; i++) {
      final med = meds[i];
      final row = i + startRow;

      if (isBlank(med.id)) {
        errors.add('Row $row: Medication missing "id".');
      }
      if (isBlank(med.group)) {
        errors.add('Row $row: Medication missing "group".');
      }
      if (isBlank(med.name)) {
        errors.add('Row $row: Medication missing "name".');
      }
      if (med.route != null && med.route!.any(isBlank)) {
        errors.add('Row $row: Medication has blank entry in "route" list.');
      }
    }

    return errors;
  }

  /// ─────────────────────────────────────────────
  /// 🧴 Consumable Validation
  /// ─────────────────────────────────────────────
  static List<String> validateConsumables(
    List<ConsumableItem> items, {
    int startRow = 2,
  }) {
    final errors = <String>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final row = i + startRow;

      if (isBlank(item.id)) {
        errors.add('Row $row: Consumable missing "id".');
      }
      if (isBlank(item.group)) {
        errors.add('Row $row: Consumable missing "group".');
      }
      if (isBlank(item.name)) {
        errors.add('Row $row: Consumable missing "name".');
      }
    }

    return errors;
  }

  /// ─────────────────────────────────────────────
  /// 🛠️ Equipment Validation
  /// ─────────────────────────────────────────────
  static List<String> validateEquipment(
    List<EquipmentItem> items, {
    int startRow = 2,
  }) {
    final errors = <String>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final row = i + startRow;

      if (isBlank(item.id)) {
        errors.add('Row $row: Equipment missing "id".');
      }
      if (isBlank(item.group)) {
        errors.add('Row $row: Equipment missing "group".');
      }
      if (isBlank(item.name)) {
        errors.add('Row $row: Equipment missing "name".');
      }
    }

    return errors;
  }
}
