// lib/features/inventory/records/issues/controllers/form/issue_form_validator.dart

import 'package:afyakit/features/inventory/items/extensions/item_type_x.dart';

import 'package:afyakit/features/inventory/records/issues/extensions/issue_type_x.dart';
import 'package:afyakit/features/inventory/records/issues/models/issue_entry.dart';
import 'package:afyakit/features/inventory/records/issues/models/issue_record.dart';
import 'package:afyakit/features/inventory/records/issues/models/validation_result.dart';

class IssueFormValidator {
  const IssueFormValidator._();

  /// Lightweight client-side validation before submission.
  ///
  /// This is UX validation only.
  /// The backend remains authoritative for business rules,
  /// authentication, lifecycle state and stock availability.
  static ValidationResult validateSubmission({
    required IssueRecord record,
    required List<IssueEntry> entries,
  }) {
    if (record.fromStore.trim().isEmpty) {
      return ValidationResult.invalid('Source store is required.');
    }

    if (record.type == IssueType.transfer) {
      if (record.toStore.trim().isEmpty) {
        return ValidationResult.invalid('Destination is required.');
      }

      if (record.fromStore.toLowerCase() == record.toStore.toLowerCase()) {
        return ValidationResult.invalid('Cannot transfer to the same store.');
      }
    }

    if (entries.isEmpty) {
      return ValidationResult.invalid('At least one item is required.');
    }

    for (final entry in entries) {
      final result = _validateEntry(entry);

      if (!result.isValid) {
        return result;
      }
    }

    return ValidationResult.valid();
  }

  static ValidationResult _validateEntry(IssueEntry entry) {
    if (entry.itemId.trim().isEmpty) {
      return ValidationResult.invalid('Item ID is required.');
    }

    if (entry.itemName.trim().isEmpty) {
      return ValidationResult.invalid('Item name is required.');
    }

    if (entry.itemGroup.trim().isEmpty) {
      return ValidationResult.invalid('Item group is required.');
    }

    if (entry.itemType == ItemType.unknown) {
      return ValidationResult.invalid('Unknown item type.');
    }

    if (entry.batchId?.trim().isEmpty ?? true) {
      return ValidationResult.invalid('Batch is required.');
    }

    if (entry.quantity <= 0) {
      return ValidationResult.invalid('Quantity must be greater than 0.');
    }

    return ValidationResult.valid();
  }
}
