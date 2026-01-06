// lib/features/inventory_locations/inventory_location_validator.dart

import 'package:afyakit/features/inventory/locations/inventory_location_type_enum.dart';

class InventoryLocationValidator {
  static List<String> validate({
    required String name,
    required InventoryLocationType type,
  }) {
    final errors = <String>[];

    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      errors.add('Location name cannot be empty.');
    } else if (trimmed.length < 3) {
      errors.add('Location name must be at least 3 characters.');
    }

    final regex = RegExp(r'^[a-zA-Z0-9\s\-_]+$');
    if (!regex.hasMatch(trimmed)) {
      errors.add('Location name contains invalid characters.');
    }

    return errors;
  }
}
