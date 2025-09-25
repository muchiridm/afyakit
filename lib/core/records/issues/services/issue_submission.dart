import 'package:afyakit/core/records/issues/extensions/issue_type_x.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import 'package:afyakit/core/records/issues/models/issue_entry.dart';
import 'package:afyakit/core/records/issues/models/issue_record.dart';

import 'package:afyakit/core/batches/models/batch_record.dart';
import 'package:afyakit/core/inventory/models/items/medication_item.dart';
import 'package:afyakit/core/inventory/models/items/consumable_item.dart';
import 'package:afyakit/core/inventory/models/items/equipment_item.dart';
import 'package:afyakit/core/inventory/extensions/item_type_x.dart';

class IssueSubmission {
  final IssueRecord record;
  final List<IssueEntry> entries;

  IssueSubmission({required this.record, required this.entries});
}

/// Builds a single Issue (fromStore → toStore) plus its entries
/// from the cart. The service will assign the Issue id from a
/// deterministic requestKey, so we keep `id: ''` here.
List<IssueSubmission> buildIssueSubmissionFromCart({
  required Map<String, Map<String, int>> cart, // {itemId: {batchId: qty}}
  required String fromStore,
  required String toStore,
  required DateTime date,
  required IssueType type,
  required String requestedBy,
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

      final batch = batches.firstWhereOrNull((b) => b.id == batchId);
      if (batch == null) continue;

      final itemType = batch.itemType;

      String name = 'Unnamed Item';
      String group = 'Unknown';
      String? strength;
      String? size;
      String? formulation;
      String? packSize;

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
          }
          break;
        case ItemType.consumable:
          final c = consumables.firstWhereOrNull((x) => x.id == itemId);
          if (c != null) {
            name = c.name;
            group = c.group;
            size = c.size;
            packSize = c.packSize;
          }
          break;
        case ItemType.equipment:
          final e = equipment.firstWhereOrNull((x) => x.id == itemId);
          if (e != null) {
            name = e.name;
            group = e.group;
          }
          break;
        case ItemType.unknown:
          break;
      }

      entries.add(
        IssueEntry(
          id: uuid.v4(), // stable per entry; used as subdoc id
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
        ),
      );
    }
  }

  final record = IssueRecord(
    id: '', // ← service will assign deterministic id from requestKey
    fromStore: fromStore,
    toStore: type == IssueType.dispose ? 'Disposal' : toStore,
    type: type,
    status: status,
    dateRequested: date,
    dateApproved: approvedAt,
    dateIssuedOrReceived: null,
    requestedByUid: requestedBy,
    approvedByUid: approvedBy,
    actionedByUid: issuedBy,
    actionedByName: issuedByName,
    actionedByRole: issuedByRole,
    note: note,
    entries: entries,
  );

  return [IssueSubmission(record: record, entries: entries)];
}
