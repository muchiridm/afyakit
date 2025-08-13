// lib/features/records/issues/controllers/engines/issue_submit_engine.dart

import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/features/inventory/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/models/items/equipment_item.dart';
import 'package:afyakit/features/inventory/models/items/medication_item.dart';
import 'package:afyakit/features/records/issues/controllers/states/multi_cart_state.dart';
import 'package:afyakit/features/records/issues/models/enums/issue_type_enum.dart';
import 'package:afyakit/features/records/issues/services/build_issue_submission_from_cart.dart';
import 'package:afyakit/features/records/issues/services/issue_service.dart';
import 'package:afyakit/features/records/issues/services/issue_validator.dart';

class SubmitResult {
  final bool allSuccess;
  final Map<String, String> storeErrors;
  final List<String> okStores;

  const SubmitResult({
    required this.allSuccess,
    required this.storeErrors,
    this.okStores = const [],
  });
}

class IssueFormEngine {
  final IssueService service;

  IssueFormEngine(this.service);

  Future<SubmitResult> submitMultiCart({
    required String userId,
    required MultiCartState cartState,
    required List<BatchRecord> batches,
    required List<MedicationItem> meds,
    required List<ConsumableItem> cons,
    required List<EquipmentItem> equips,
  }) async {
    var allSuccess = true;
    final errors = <String, String>{};

    for (final entry in cartState.cartsByStore.entries) {
      final storeId = entry.key;
      final cart = entry.value;

      if (cart.isEmpty) continue;

      if (cart.type != IssueType.dispose &&
          (cart.destination?.trim().isEmpty ?? true)) {
        allSuccess = false;
        errors[storeId] = 'Destination missing for store $storeId';
        continue;
      }

      if (cart.fromStore?.trim().isEmpty ?? true) {
        allSuccess = false;
        errors[storeId] = 'Origin store not set for $storeId';
        continue;
      }

      final submissions = buildIssueSubmissionFromCart(
        cart: cart.batchQuantities,
        fromStore: cart.fromStore!,
        batches: batches,
        medications: meds,
        consumables: cons,
        equipment: equips,
        type: cart.type,
        toStore: cart.destination ?? '',
        date: cart.requestDate,
        requestedBy: userId,
        note: cart.note,
        status: 'pending',
        approvedBy: null,
        approvedAt: null,
        issuedBy: null,
        issuedByName: null,
        issuedByRole: null,
      );

      if (submissions.isEmpty) {
        allSuccess = false;
        errors[storeId] = 'Nothing to submit for $storeId';
        continue;
      }

      for (final s in submissions) {
        final result = IssueValidator.validateSubmission(
          record: s.record,
          entries: s.entries,
        );

        if (!result.isValid) {
          allSuccess = false;
          errors[storeId] =
              result.errorMessage ?? 'Invalid submission for $storeId';
          continue;
        }

        try {
          await service.addIssueWithEntries(s.record, s.entries);
        } catch (e) {
          allSuccess = false;
          errors[storeId] = 'Submission failed for $storeId: $e';
        }
      }
    }

    return SubmitResult(allSuccess: allSuccess, storeErrors: errors);
  }
}
