import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import 'package:afyakit/features/records/issues/models/issue_entry.dart';
import 'package:afyakit/features/records/issues/models/issue_record.dart';
import 'package:afyakit/features/records/issues/models/enums/issue_type_enum.dart';

import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/features/inventory/models/items/medication_item.dart';
import 'package:afyakit/features/inventory/models/items/consumable_item.dart';
import 'package:afyakit/features/inventory/models/items/equipment_item.dart';
import 'package:afyakit/features/inventory/models/item_type_enum.dart';

class IssueSubmission {
  final IssueRecord record;
  final List<IssueEntry> entries;

  IssueSubmission({required this.record, required this.entries});
}

/// 🔧 Builds grouped issue submissions by `fromStore → toStore`
/// One `IssueRecord` is created for each `fromStore` involved.
List<IssueSubmission> buildIssueSubmissionFromCart({
  required Map<String, Map<String, int>> cart,
  required String fromStore, // ✅ Now required from CartState
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

      // 🔍 Lookup item details
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
        ),
      );
    }
  }

  // 🧾 Final record
  final record = IssueRecord(
    id: uuid.v4(),
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
