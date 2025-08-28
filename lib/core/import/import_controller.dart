import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/import/import_parser.dart';
import 'package:afyakit/core/import/import_validator.dart';

import 'package:afyakit/core/inventory/controllers/forms/medication_controller.dart';
import 'package:afyakit/core/inventory/controllers/forms/consumable_controller.dart';
import 'package:afyakit/core/inventory/controllers/forms/equipment_controller.dart';

import 'package:afyakit/core/inventory/models/items/medication_item.dart';
import 'package:afyakit/core/inventory/models/items/consumable_item.dart';
import 'package:afyakit/core/inventory/models/items/equipment_item.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/services/dialog_service.dart';

final importControllerProvider =
    StateNotifierProvider.autoDispose<ImportController, AsyncValue<void>>(
      (ref) => ImportController(ref),
    );

class ImportController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  ImportController(this.ref) : super(const AsyncData(null));

  List<MedicationItem> _medications = [];
  List<ConsumableItem> _consumables = [];
  List<EquipmentItem> _equipment = [];

  // ─────────────────────────────────────────────────────
  // 🧠 PARSING
  // ─────────────────────────────────────────────────────

  void parseFile(Uint8List bytes) {
    _medications = ImportParser.parseMedications(bytes);
    _consumables = ImportParser.parseConsumables(bytes);
    _equipment = ImportParser.parseEquipment(bytes);
  }

  void reset() {
    _medications.clear();
    _consumables.clear();
    _equipment.clear();
    state = const AsyncData(null);
  }

  Map<String, int> get parsedCounts => {
    'medications': _medications.length,
    'consumables': _consumables.length,
    'equipment': _equipment.length,
  };

  int get totalCount =>
      _medications.length + _consumables.length + _equipment.length;

  // ─────────────────────────────────────────────────────
  // 🚀 COMMIT ALL
  // ─────────────────────────────────────────────────────

  Future<void> commitImport() async {
    state = const AsyncLoading();

    final allErrors = [
      ...ImportValidator.validateMedications(_medications),
      ...ImportValidator.validateConsumables(_consumables),
      ...ImportValidator.validateEquipment(_equipment),
    ];

    if (allErrors.isNotEmpty) {
      await _showValidationErrors(allErrors);
      state = const AsyncData(null);
      return;
    }

    try {
      final medCtrl = ref.read(medicationControllerProvider);
      final consCtrl = ref.read(consumableControllerProvider);
      final equipCtrl = ref.read(equipmentControllerProvider);

      await Future.wait([
        ..._medications.map(medCtrl.create),
        ..._consumables.map(consCtrl.create),
        ..._equipment.map(equipCtrl.create),
      ]);

      SnackService.showSuccess('✅ All items imported successfully.');
      reset();
    } catch (e, stack) {
      state = AsyncError(e, stack);
      SnackService.showError('❌ Import failed:\n$e');
    }
  }

  // ─────────────────────────────────────────────────────
  // 🎯 INDIVIDUAL IMPORTS
  // ─────────────────────────────────────────────────────

  Future<void> importMedications(Uint8List bytes) => _importOne<MedicationItem>(
    bytes: bytes,
    parser: ImportParser.parseMedications,
    validator: ImportValidator.validateMedications,
    controller: ref.read(medicationControllerProvider),
    label: 'medications',
  );

  Future<void> importConsumables(Uint8List bytes) => _importOne<ConsumableItem>(
    bytes: bytes,
    parser: ImportParser.parseConsumables,
    validator: ImportValidator.validateConsumables,
    controller: ref.read(consumableControllerProvider),
    label: 'consumables',
  );

  Future<void> importEquipment(Uint8List bytes) => _importOne<EquipmentItem>(
    bytes: bytes,
    parser: ImportParser.parseEquipment,
    validator: ImportValidator.validateEquipment,
    controller: ref.read(equipmentControllerProvider),
    label: 'equipment items',
  );

  // ─────────────────────────────────────────────────────
  // 🔁 DRY INTERNAL METHOD
  // ─────────────────────────────────────────────────────

  Future<void> _importOne<T>({
    required Uint8List bytes,
    required List<T> Function(Uint8List) parser,
    required List<String> Function(List<T>) validator,
    required dynamic controller, // Should have `.create()`
    required String label,
  }) async {
    final items = parser(bytes);
    final errors = validator(items);

    if (errors.isNotEmpty) {
      await _showValidationErrors(errors);
      return;
    }

    try {
      for (final item in items) {
        await controller.create(item);
      }
      SnackService.showSuccess('✅ Imported ${items.length} $label.');
    } catch (e) {
      SnackService.showError('❌ Failed to import $label:\n$e');
    }
  }

  // ─────────────────────────────────────────────────────
  // ⚠️ SHARED HELPER
  // ─────────────────────────────────────────────────────

  Future<void> _showValidationErrors(List<String> errors) async {
    await DialogService.confirm(
      title: 'Validation Errors',
      content: errors.join('\n'),
    );
  }
}
