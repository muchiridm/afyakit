import 'package:afyakit/modules/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/modules/inventory/records/issues/extensions/issue_type_x.dart';
import 'package:afyakit/modules/inventory/records/issues/models/issue_entry.dart';
import 'package:afyakit/modules/inventory/records/issues/models/issue_record.dart';
import 'package:afyakit/modules/inventory/records/issues/models/validation_result.dart';

class IssueValidator {
  /// Validates a single IssueRecord
  static ValidationResult validateRecord(IssueRecord record) {
    final errors = <String>[];

    if (record.fromStore.trim().isEmpty) {
      errors.add('Source store is required.');
    }

    if (record.toStore.trim().isEmpty) {
      errors.add('Destination is required.');
    }

    if (record.status.trim().isEmpty) {
      errors.add('Status is required.');
    }

    if (record.requestedByUid.trim().isEmpty) {
      errors.add('Requested by UID is required.');
    }

    if (record.type == IssueType.transfer &&
        record.fromStore.toLowerCase() == record.toStore.toLowerCase()) {
      errors.add('Cannot transfer to the same store.');
    }

    switch (record.status.toLowerCase()) {
      case 'approved':
        if (record.approvedByUid?.trim().isEmpty ?? true) {
          errors.add('Approved by UID is required.');
        }
        if (record.dateApproved == null) {
          errors.add('Approval date is required.');
        }
        break;

      case 'issued':
        if (record.actionedByUid?.trim().isEmpty ?? true) {
          errors.add('Issuer UID is required.');
        }
        if (record.dateIssuedOrReceived == null) {
          errors.add('Issued date is required.');
        }
        break;

      case 'rejected':
        if (record.approvedByUid?.trim().isEmpty ?? true) {
          errors.add('Rejected by UID is required.');
        }
        if (record.dateApproved == null) {
          errors.add('Rejection date is required.');
        }
        break;

      case 'pending':
        // nothing extra
        break;

      default:
        errors.add('Unknown status "${record.status}".');
    }

    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors.first);
  }

  /// Validates a single IssueEntry
  static ValidationResult validateEntry(IssueEntry entry) {
    final errors = <String>[];

    if (entry.itemId.trim().isEmpty) {
      errors.add('Item ID is required.');
    }

    if (entry.itemName.trim().isEmpty) {
      errors.add('Item name is required.');
    }

    if (entry.itemGroup.trim().isEmpty) {
      errors.add('Item group is required.');
    }

    if (entry.quantity <= 0) {
      errors.add('Quantity must be greater than 0.');
    }

    if (entry.itemType == ItemType.unknown) {
      errors.add('Unknown item type.');
    }

    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors.first);
  }

  /// Validates both record and its entries
  static ValidationResult validateSubmission({
    required IssueRecord record,
    required List<IssueEntry> entries,
  }) {
    final recordResult = validateRecord(record);
    if (!recordResult.isValid) return recordResult;

    for (final entry in entries) {
      final result = validateEntry(entry);
      if (!result.isValid) return result;
    }

    return ValidationResult.valid();
  }
}
