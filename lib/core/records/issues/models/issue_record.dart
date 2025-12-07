// lib/core/records/issues/models/issue_record.dart

import 'package:afyakit/core/records/issues/extensions/issue_status_x.dart';
import 'package:afyakit/core/records/issues/extensions/issue_type_x.dart';
import 'package:afyakit/core/records/issues/models/issue_entry.dart';
import 'package:afyakit/shared/utils/parsers/parse_date.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_user_display.dart';

class IssueRecord {
  final String id;
  final String fromStore;
  final String toStore;
  final IssueType type;
  final String status;
  final DateTime dateRequested;
  final DateTime? dateApproved;
  final DateTime? dateIssuedOrReceived;

  // ── Requester ──────────────────────────────────────────────
  final String requestedByUid;
  final String? requestedByName;
  final String? requestedByEmail;

  // ── Approver ──────────────────────────────────────────────
  final String? approvedByUid;
  final String? approvedByName;
  final String? approvedByEmail;

  // ── Actioner (issued / received / disposed / dispensed) ───
  final String? actionedByUid;
  final String? actionedByName;
  final String? actionedByRole;
  final String? actionedByEmail;

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
    // requester
    required this.requestedByUid,
    this.requestedByName,
    this.requestedByEmail,
    // approver
    this.approvedByUid,
    this.approvedByName,
    this.approvedByEmail,
    // actioner
    this.actionedByUid,
    this.actionedByName,
    this.actionedByRole,
    this.actionedByEmail,
    this.note,
    required this.entries,
  });

  Map<String, dynamic> toMap() => {
    'fromStore': fromStore,
    'toStore': toStore,
    'type': type.name,
    'status': status,
    'dateRequested': dateRequested.toIso8601String(),
    'dateApproved': dateApproved?.toIso8601String(),
    'dateIssuedOrReceived': dateIssuedOrReceived?.toIso8601String(),

    // requester snapshot
    'requestedByUid': requestedByUid,
    'requestedByName': requestedByName,
    'requestedByEmail': requestedByEmail,

    // approver snapshot
    'approvedByUid': approvedByUid,
    'approvedByName': approvedByName,
    'approvedByEmail': approvedByEmail,

    // actioner snapshot
    'actionedByUid': actionedByUid,
    'actionedByName': actionedByName,
    'actionedByRole': actionedByRole,
    'actionedByEmail': actionedByEmail,

    'note': note,
    // entries still in subcollection normally; we also sometimes
    // persist a denormalised "entries" array elsewhere.
  };

  factory IssueRecord.fromMap(String id, Map<String, dynamic> map) {
    final parsedType = IssueTypeX.fromString(map['type'] ?? 'transfer');

    // if someone saved entries inline, hydrate them
    final parsedEntries =
        (map['entries'] as List?)
            ?.map(
              (e) => IssueEntry.fromMap(
                'entry_auto',
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList() ??
        <IssueEntry>[];

    return IssueRecord(
      id: id,
      fromStore: map['fromStore'] ?? '',
      toStore: map['toStore'] ?? map['to'] ?? '',
      type: parsedType,
      status: map['status'] ?? 'pending',
      dateRequested: parseDate(map['dateRequested'])!,
      dateApproved: parseDate(map['dateApproved']),
      dateIssuedOrReceived: parseDate(map['dateIssuedOrReceived']),

      // requester snapshot
      requestedByUid: map['requestedByUid'] ?? '',
      requestedByName: map['requestedByName'],
      requestedByEmail: map['requestedByEmail'],

      // approver snapshot
      approvedByUid: map['approvedByUid'],
      approvedByName: map['approvedByName'],
      approvedByEmail: map['approvedByEmail'],

      // actioner snapshot
      actionedByUid: map['actionedByUid'],
      actionedByName: map['actionedByName'],
      actionedByRole: map['actionedByRole'],
      actionedByEmail: map['actionedByEmail'],

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
    // requester
    String? requestedByUid,
    String? requestedByName,
    String? requestedByEmail,
    // approver
    String? approvedByUid,
    String? approvedByName,
    String? approvedByEmail,
    // actioner
    String? actionedByUid,
    String? actionedByName,
    String? actionedByRole,
    String? actionedByEmail,
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
      requestedByName: requestedByName ?? this.requestedByName,
      requestedByEmail: requestedByEmail ?? this.requestedByEmail,

      approvedByUid: approvedByUid ?? this.approvedByUid,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedByEmail: approvedByEmail ?? this.approvedByEmail,

      actionedByUid: actionedByUid ?? this.actionedByUid,
      actionedByName: actionedByName ?? this.actionedByName,
      actionedByRole: actionedByRole ?? this.actionedByRole,
      actionedByEmail: actionedByEmail ?? this.actionedByEmail,

      note: note ?? this.note,
      entries: entries ?? this.entries,
    );
  }

  // ── Derived helpers ────────────────────────────────────────

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

  /// Snapshot-based labels (fall back to UID if name/email missing).
  String get requestedByLabel => resolveUserDisplay(
    displayName: requestedByName,
    email: requestedByEmail,
    uid: requestedByUid,
  );

  // lib/core/records/issues/models/issue_record.dart

  String? get approvedByLabel {
    final hasName = approvedByName != null && approvedByName!.trim().isNotEmpty;
    final hasEmail =
        approvedByEmail != null && approvedByEmail!.trim().isNotEmpty;

    // If we don't have a human-readable snapshot, don't show the field at all.
    if (!hasName && !hasEmail) {
      return null;
    }

    return resolveUserDisplay(
      displayName: approvedByName,
      email: approvedByEmail,
      uid: approvedByUid ?? '',
    );
  }

  String? get actionedByLabel {
    // Only show a label if we have a human-readable snapshot.
    final hasName = actionedByName != null && actionedByName!.trim().isNotEmpty;
    final hasEmail =
        actionedByEmail != null && actionedByEmail!.trim().isNotEmpty;

    if (!hasName && !hasEmail) {
      // Old behaviour: no name/email → no "Actioned By" row.
      return null;
    }

    return resolveUserDisplay(
      displayName: actionedByName,
      email: actionedByEmail,
      uid: actionedByUid ?? '',
    );
  }
}
