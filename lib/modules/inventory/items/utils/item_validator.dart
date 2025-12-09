import 'package:afyakit/modules/inventory/items/extensions/item_type_x.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final itemValidatorProvider = Provider<ItemValidator>((ref) => ItemValidator());

class ItemValidator {
  List<String> validate(ItemType type, Map<String, dynamic> item) {
    switch (type) {
      case ItemType.medication:
        return _validateMedication(item);
      case ItemType.consumable:
        return _validateConsumable(item);
      case ItemType.equipment:
        return _validateEquipment(item);
      case ItemType.unknown:
        return ['❌ Cannot validate unknown item type.'];
    }
  }

  List<String> _validateCommon(Map<String, dynamic> item) {
    final errors = <String>[];

    final name = item['name'];
    final group = item['group'];
    final reorder = item['reorderLevel'];
    final proposed = item['proposedOrder'];

    if (name is! String || name.trim().isEmpty) {
      errors.add("⚠️ Name is required.");
    }

    if (group is! String || group.trim().isEmpty) {
      errors.add("⚠️ Group is required.");
    }

    if (reorder != null && (reorder is! int || reorder < 0)) {
      errors.add("⚠️ Reorder level must be 0 or greater.");
    }

    if (proposed != null && (proposed is! int || proposed < 0)) {
      errors.add("⚠️ Proposed order must be 0 or greater.");
    }

    return errors;
  }

  List<String> _validateMedication(Map<String, dynamic> item) {
    final errors = _validateCommon(item);

    final route = item['route'];
    if (route != null) {
      if (route is! List) {
        errors.add("⚠️ Route must be a list of strings.");
      } else if (route.any((e) => e is! String || e.trim().isEmpty)) {
        errors.add("⚠️ Route must only contain non-empty strings.");
      }
    }

    return errors;
  }

  List<String> _validateConsumable(Map<String, dynamic> item) {
    final errors = _validateCommon(item);

    final unit = item['unit'];
    if (unit != null && (unit is! String || unit.trim().isEmpty)) {
      errors.add("⚠️ Unit, if provided, must be a non-empty string.");
    }

    return errors;
  }

  List<String> _validateEquipment(Map<String, dynamic> item) {
    final errors = _validateCommon(item);

    final model = item['model'];
    if (model != null && (model is! String || model.trim().isEmpty)) {
      errors.add("⚠️ Model, if provided, must be a non-empty string.");
    }

    return errors;
  }
}
