// lib/core/records/issues/services/issue_submission.dart

import 'package:afyakit/modules/inventory/records/issues/extensions/issue_type_x.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import 'package:afyakit/modules/inventory/records/issues/models/issue_entry.dart';
import 'package:afyakit/modules/inventory/records/issues/models/issue_record.dart';

import 'package:afyakit/modules/inventory/batches/models/batch_record.dart';
import 'package:afyakit/modules/inventory/items/models/items/medication_item.dart';
import 'package:afyakit/modules/inventory/items/models/items/consumable_item.dart';
import 'package:afyakit/modules/inventory/items/models/items/equipment_item.dart';
import 'package:afyakit/modules/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';

class IssueSubmission {
  final IssueRecord record;
  final List<IssueEntry> entries;

  IssueSubmission({required this.record, required this.entries});
}

/// Builds a single Issue (fromStore → toStore) plus its entries
/// from the cart, and denormalizes SKU + batch info into each entry.
List<IssueSubmission> buildIssueSubmissionFromCart({
  required Map<String, Map<String, int>> cart, // {itemId: {batchId: qty}}
  required String fromStore,
  required String toStore,
  required DateTime date,
  required IssueType type,

  /// Full requester, so we can snapshot uid + name + email.
  required AuthUser requester,

  required List<BatchRecord> batches,
  required List<MedicationItem> medications,
  required List<ConsumableItem> consumables,
  required List<EquipmentItem> equipment,
  String status = 'pending',
  String? approvedBy,
  DateTime? approvedAt,
  String? issuedBy,
  String? issuedByName,
  String? issuedByRole,
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

      // 1) batch → itemType + expiry (+ maybe brand)
      final batch = batches.firstWhereOrNull((b) => b.id == batchId);
      if (batch == null) continue;

      final itemType = batch.itemType;

      // defaults
      String name = 'Unnamed Item';
      String group = 'Unknown';
      String? strength;
      String? size;
      String? formulation;
      String? packSize;
      String? brandName;
      DateTime? expiry;

      // 2) SKU (main source for brand)
      switch (itemType) {
        case ItemType.medication:
          final m = medications.firstWhereOrNull((x) => x.id == itemId);
          if (m != null) {
            name = m.name;
            group = m.group;
            strength = m.strength;
            size = m.size;
            formulation = m.formulation;
            packSize = m.packSize;
            if (m.brandName != null && m.brandName!.trim().isNotEmpty) {
              brandName = m.brandName!.trim();
            }
          }
          break;

        case ItemType.consumable:
          final c = consumables.firstWhereOrNull((x) => x.id == itemId);
          if (c != null) {
            name = c.name;
            group = c.group;
            size = c.size;
            packSize = c.packSize;
            if (c.brandName != null && c.brandName!.trim().isNotEmpty) {
              brandName = c.brandName!.trim();
            }
          }
          break;

        case ItemType.equipment:
          final e = equipment.firstWhereOrNull((x) => x.id == itemId);
          if (e != null) {
            name = e.name;
            group = e.group;
            // equipment → no brandName in your models → leave null
          }
          break;

        case ItemType.unknown:
          break;
      }

      // 3) expiry from batch
      expiry = batch.expiryDate ?? batch.expiryDate;

      // 4) EXTRA fallback for brand: batch brand
      if (brandName == null || brandName.trim().isEmpty) {
        final dynamic raw = (batch as dynamic);
        final candidate = () {
          try {
            if (raw.brandName != null) return raw.brandName as String;
          } catch (_) {}
          try {
            if (raw.brand != null) return raw.brand as String;
          } catch (_) {}
          return null;
        }();

        if (candidate != null && candidate.trim().isNotEmpty) {
          brandName = candidate.trim();
        }
      }

      // 5) build entry
      entries.add(
        IssueEntry(
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

  final record = IssueRecord(
    id: '',
    fromStore: fromStore,
    toStore: type == IssueType.dispose ? 'Disposal' : toStore,
    type: type,
    status: status,
    dateRequested: date,
    dateApproved: approvedAt,
    dateIssuedOrReceived: null,

    // requester snapshot
    requestedByUid: requester.uid,
    requestedByName: requester.displayName,
    requestedByEmail: requester.email,

    // approver + actioner start empty here
    approvedByUid: approvedBy,
    approvedByName: null,
    approvedByEmail: null,
    actionedByUid: issuedBy,
    actionedByName: issuedByName,
    actionedByRole: issuedByRole,
    actionedByEmail: null,

    note: note,
    entries: entries,
  );

  return [IssueSubmission(record: record, entries: entries)];
}
