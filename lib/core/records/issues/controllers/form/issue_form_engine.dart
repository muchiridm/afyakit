// lib/core/records/issues/controllers/form/issue_form_engine.dart

import 'package:afyakit/core/batches/models/batch_record.dart';
import 'package:afyakit/core/inventory/models/items/consumable_item.dart';
import 'package:afyakit/core/inventory/models/items/equipment_item.dart';
import 'package:afyakit/core/inventory/models/items/medication_item.dart';
import 'package:afyakit/core/records/issues/controllers/cart/multi_cart_state.dart';
import 'package:afyakit/core/records/issues/extensions/issue_type_x.dart';
import 'package:afyakit/core/records/issues/services/issue_submission.dart';
import 'package:afyakit/core/records/issues/services/issue_service.dart';
import 'package:afyakit/core/records/issues/services/issue_validator.dart';
import 'package:afyakit/hq/tenants/providers/tenant_slug_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final issueFormEngineProvider = Provider<IssueFormEngine>((ref) {
  final tenantId = ref.watch(tenantSlugProvider);
  return IssueFormEngine(IssueService(tenantId));
});

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

  /// Creates one issue per `fromStore` in the cart in an **idempotent** way.
  /// Supply a stable `requestKeyBase` (e.g., generated when the screen opens).
  Future<SubmitResult> submitMultiCart({
    required String userId,
    required MultiCartState cartState,
    required List<BatchRecord> batches,
    required List<MedicationItem> meds,
    required List<ConsumableItem> cons,
    required List<EquipmentItem> equips,
    required String requestKeyBase, // 👈 NEW
  }) async {
    var allSuccess = true;
    final errors = <String, String>{};
    final okStores = <String>[];

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

      var storeOk = true;
      for (var i = 0; i < submissions.length; i++) {
        final s = submissions[i];

        final validation = IssueValidator.validateSubmission(
          record: s.record,
          entries: s.entries,
        );
        if (!validation.isValid) {
          allSuccess = false;
          storeOk = false;
          errors[storeId] =
              validation.errorMessage ?? 'Invalid submission for $storeId';
          break;
        }

        try {
          // 👇 Idempotent create with deterministic doc id per (screen, store, index)
          final requestKey = '$requestKeyBase-$storeId-$i';
          await service.createIssueWithEntriesIdempotent(
            requestKey: requestKey,
            issueDraft: s.record.copyWith(id: ''), // service assigns id
            entries: s.entries,
          );
        } catch (e) {
          allSuccess = false;
          storeOk = false;
          errors[storeId] = 'Submission failed for $storeId: $e';
          break;
        }
      }

      if (storeOk) okStores.add(storeId);
    }

    return SubmitResult(
      allSuccess: allSuccess,
      storeErrors: errors,
      okStores: okStores,
    );
  }
}
