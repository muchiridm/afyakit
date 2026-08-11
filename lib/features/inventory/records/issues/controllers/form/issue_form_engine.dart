// lib/features/inventory/records/issues/controllers/form/issue_form_engine.dart

import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

import 'package:afyakit/features/inventory/batches/models/batch_record.dart';

import 'package:afyakit/features/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/features/inventory/items/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/items/models/items/equipment_item.dart';
import 'package:afyakit/features/inventory/items/models/items/medication_item.dart';

import 'package:afyakit/features/inventory/records/cart/controllers/multi_cart_state.dart';
import 'package:afyakit/features/inventory/records/issues/extensions/issue_type_x.dart';
import 'package:afyakit/features/inventory/records/issues/models/issue_entry.dart';
import 'package:afyakit/features/inventory/records/issues/models/issue_record.dart';

import 'package:afyakit/features/inventory/records/issues/services/issue_service.dart';
import 'package:afyakit/features/inventory/records/issues/controllers/form/issue_form_validator.dart';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final issueFormEngineProvider = Provider<IssueFormEngine>((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  final service = ref.read(issueServiceProvider);

  return IssueFormEngine(tenantId: tenantId, service: service);
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
  final String tenantId;
  final IssueService service;

  const IssueFormEngine({required this.tenantId, required this.service});

  /// Creates one issue per source store.
  ///
  /// [requestKeyBase] remains stable for the lifetime of the form so
  /// retries are idempotent at the backend.
  Future<SubmitResult> submitMultiCart({
    required MultiCartState cartState,
    required List<BatchRecord> batches,
    required List<MedicationItem> meds,
    required List<ConsumableItem> cons,
    required List<EquipmentItem> equips,
    required String requestKeyBase,
  }) async {
    var allSuccess = true;

    final errors = <String, String>{};
    final okStores = <String>[];

    for (final cartEntry in cartState.cartsByStore.entries) {
      final storeId = cartEntry.key;
      final cart = cartEntry.value;

      if (cart.isEmpty) continue;

      // ─────────────────────────────────────────
      // Basic UX validation
      // ─────────────────────────────────────────

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

      // ─────────────────────────────────────────
      // Build denormalised issue
      // ─────────────────────────────────────────

      final issue = _buildIssueFromCart(
        cart: cart.batchQuantities,
        fromStore: cart.fromStore!,
        toStore: cart.destination ?? '',
        date: cart.requestDate,
        type: cart.type,
        batches: batches,
        medications: meds,
        consumables: cons,
        equipment: equips,
        note: cart.note,
      );

      if (issue.entries.isEmpty) {
        allSuccess = false;
        errors[storeId] = 'Nothing to submit for $storeId';
        continue;
      }

      // Client-side validation is UX only.
      // Backend validation remains authoritative.
      final validation = IssueFormValidator.validateSubmission(
        record: issue,
        entries: issue.entries,
      );

      if (!validation.isValid) {
        allSuccess = false;

        errors[storeId] =
            validation.errorMessage ?? 'Invalid submission for $storeId';

        continue;
      }

      try {
        final requestKey = '$requestKeyBase-$storeId';

        await service.createIssueWithEntriesIdempotent(
          tenantId: tenantId,
          requestKey: requestKey,
          issueDraft: issue,
          entries: issue.entries,
        );

        okStores.add(storeId);
      } catch (e) {
        allSuccess = false;

        errors[storeId] = 'Submission failed for $storeId: $e';
      }
    }

    return SubmitResult(
      allSuccess: allSuccess,
      storeErrors: errors,
      okStores: okStores,
    );
  }

  // ─────────────────────────────────────────────
  // Cart → issue snapshot
  // ─────────────────────────────────────────────

  IssueRecord _buildIssueFromCart({
    required Map<String, Map<String, int>> cart,
    required String fromStore,
    required String toStore,
    required DateTime date,
    required IssueType type,
    required List<BatchRecord> batches,
    required List<MedicationItem> medications,
    required List<ConsumableItem> consumables,
    required List<EquipmentItem> equipment,
    String? note,
  }) {
    final uuid = const Uuid();
    final entries = <IssueEntry>[];

    for (final itemEntry in cart.entries) {
      final itemId = itemEntry.key;
      final batchQuantities = itemEntry.value;

      for (final batchEntry in batchQuantities.entries) {
        final batchId = batchEntry.key;
        final quantity = batchEntry.value;

        final batch = batches.firstWhereOrNull(
          (candidate) => candidate.id == batchId,
        );

        if (batch == null) {
          continue;
        }

        final itemType = batch.itemType;

        String name = 'Unnamed Item';
        String group = 'Unknown';

        String? strength;
        String? size;
        String? formulation;
        String? packSize;
        String? brandName;

        // ───────────────────────────────────────
        // Resolve SKU snapshot
        // ───────────────────────────────────────

        switch (itemType) {
          case ItemType.medication:
            final item = medications.firstWhereOrNull(
              (candidate) => candidate.id == itemId,
            );

            if (item != null) {
              name = item.name;
              group = item.group;
              strength = item.strength;
              size = item.size;
              formulation = item.formulation;
              packSize = item.packSize;

              final brand = item.brandName?.trim();

              if (brand != null && brand.isNotEmpty) {
                brandName = brand;
              }
            }
            break;

          case ItemType.consumable:
            final item = consumables.firstWhereOrNull(
              (candidate) => candidate.id == itemId,
            );

            if (item != null) {
              name = item.name;
              group = item.group;
              size = item.size;
              packSize = item.packSize;

              final brand = item.brandName?.trim();

              if (brand != null && brand.isNotEmpty) {
                brandName = brand;
              }
            }
            break;

          case ItemType.equipment:
            final item = equipment.firstWhereOrNull(
              (candidate) => candidate.id == itemId,
            );

            if (item != null) {
              name = item.name;
              group = item.group;
            }
            break;

          case ItemType.unknown:
            break;
        }

        final expiry = batch.expiryDate;

        // Fallback to a brand stored directly on the batch.
        if (brandName == null || brandName.isEmpty) {
          final dynamic rawBatch = batch;

          String? candidate;

          try {
            candidate = rawBatch.brandName as String?;
          } catch (_) {}

          if (candidate == null || candidate.trim().isEmpty) {
            try {
              candidate = rawBatch.brand as String?;
            } catch (_) {}
          }

          if (candidate != null && candidate.trim().isNotEmpty) {
            brandName = candidate.trim();
          }
        }

        entries.add(
          IssueEntry(
            // Local only. Backend generates deterministic e_XXXX ids.
            id: uuid.v4(),
            itemId: itemId,
            itemType: itemType,
            itemName: name,
            itemGroup: group,
            strength: strength,
            size: size,
            formulation: formulation,
            packSize: packSize,
            itemTypeLabel: itemType.name,
            batchId: batchId,
            quantity: quantity,
            brand: brandName,
            expiry: expiry,
          ),
        );
      }
    }

    return IssueRecord(
      id: '',
      fromStore: fromStore,
      toStore: type == IssueType.dispose ? 'Disposal' : toStore,
      type: type,
      status: 'pending',
      dateRequested: date,
      dateApproved: null,
      dateIssuedOrReceived: null,

      // Backend-owned fields.
      requestedByUid: '',
      requestedByName: null,
      requestedByEmail: null,

      approvedByUid: null,
      approvedByName: null,
      approvedByEmail: null,

      actionedByUid: null,
      actionedByName: null,
      actionedByRole: null,
      actionedByEmail: null,

      note: note,
      entries: entries,
    );
  }
}
