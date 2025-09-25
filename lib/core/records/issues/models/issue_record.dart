import 'package:afyakit/core/records/issues/extensions/issue_status_x.dart';
import 'package:afyakit/core/records/issues/extensions/issue_type_x.dart';
import 'package:afyakit/core/records/issues/models/issue_entry.dart';
import 'package:afyakit/shared/utils/parsers/parse_date.dart';

class IssueRecord {
  final String id;
  final String fromStore; // store_001
  final String toStore; // store_002
  final IssueType type;
  final String status;
  final DateTime dateRequested;
  final DateTime? dateApproved;
  final DateTime? dateIssuedOrReceived;

  final String requestedByUid;
  final String? approvedByUid;
  final String? actionedByUid;
  final String? actionedByName;
  final String? actionedByRole;
  final String? note;

  final List<IssueEntry> entries;

  IssueRecord({
    required this.id,
    required this.fromStore,
    required this.toStore,
    required this.type,
    required this.status,
    required this.dateRequested,
    this.dateApproved,
    this.dateIssuedOrReceived,
    required this.requestedByUid,
    this.approvedByUid,
    this.actionedByUid,
    this.actionedByName,
    this.actionedByRole,
    this.note,
    required this.entries,
  });

  // 🔁 Firestore serialization
  Map<String, dynamic> toMap() => {
    'fromStore': fromStore,
    'toStore': toStore, // ✅ keep canonical
    'type': type.name,
    'status': status,
    'dateRequested': dateRequested.toIso8601String(),
    'dateApproved': dateApproved?.toIso8601String(),
    'dateIssuedOrReceived': dateIssuedOrReceived?.toIso8601String(),
    'requestedByUid': requestedByUid,
    'approvedByUid': approvedByUid,
    'actionedByUid': actionedByUid,
    'actionedByName': actionedByName,
    'actionedByRole': actionedByRole,
    'note': note,
    // ⚠️ Entries are in subcollection; keep doc lean.
  };

  factory IssueRecord.fromMap(String id, Map<String, dynamic> map) {
    final parsedType = IssueTypeX.fromString(map['type'] ?? 'transfer');

    final parsedEntries =
        (map['entries'] as List?)
            ?.map(
              (e) => IssueEntry.fromMap(
                'entry_auto',
                Map<String, dynamic>.from(e),
              ),
            )
            .toList() ??
        <IssueEntry>[];

    return IssueRecord(
      id: id,
      fromStore: map['fromStore'] ?? '',
      toStore: map['toStore'] ?? map['to'] ?? '', // legacy fallback
      type: parsedType,
      status: map['status'] ?? 'pending',
      dateRequested: parseDate(map['dateRequested'])!,
      dateApproved: parseDate(map['dateApproved']),
      dateIssuedOrReceived: parseDate(map['dateIssuedOrReceived']),
      requestedByUid: map['requestedByUid'] ?? '',
      approvedByUid: map['approvedByUid'],
      actionedByUid: map['actionedByUid'],
      actionedByName: map['actionedByName'],
      actionedByRole: map['actionedByRole'],
      note: map['note'],
      entries: parsedEntries,
    );
  }

  IssueRecord copyWith({
    String? id,
    String? fromStore,
    String? toStore,
    IssueType? type,
    String? status,
    DateTime? dateRequested,
    DateTime? dateApproved,
    DateTime? dateIssuedOrReceived,
    String? requestedByUid,
    String? approvedByUid,
    String? actionedByUid,
    String? actionedByName,
    String? actionedByRole,
    String? note,
    List<IssueEntry>? entries,
  }) {
    return IssueRecord(
      id: id ?? this.id,
      fromStore: fromStore ?? this.fromStore,
      toStore: toStore ?? this.toStore,
      type: type ?? this.type,
      status: status ?? this.status,
      dateRequested: dateRequested ?? this.dateRequested,
      dateApproved: dateApproved ?? this.dateApproved,
      dateIssuedOrReceived: dateIssuedOrReceived ?? this.dateIssuedOrReceived,
      requestedByUid: requestedByUid ?? this.requestedByUid,
      approvedByUid: approvedByUid ?? this.approvedByUid,
      actionedByUid: actionedByUid ?? this.actionedByUid,
      actionedByName: actionedByName ?? this.actionedByName,
      actionedByRole: actionedByRole ?? this.actionedByRole,
      note: note ?? this.note,
      entries: entries ?? this.entries,
    );
  }

  // ───── Computed Getters (safe) ─────────────────────
  IssueStatus get statusEnum => IssueStatusX.fromString(status);
  String get statusLabel => statusEnum.label;
  bool get isFinalStatus => statusEnum.isFinal;

  int get totalQuantity => entries.fold(0, (sum, e) => sum + e.quantity);

  String get firstItemName =>
      entries.isEmpty ? 'Items' : entries.first.itemName;

  String get displayTitle {
    if (entries.isEmpty) return 'Items';
    if (entries.length == 1) return entries.first.itemName;
    return '${entries.first.itemName} + ${entries.length - 1}';
  }
}
