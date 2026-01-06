import 'package:afyakit/features/inventory/records/issues/extensions/issue_type_x.dart';
import 'package:afyakit/features/inventory/records/issues/models/issue_record.dart';

class IssueFormState {
  final IssueType type;
  final DateTime requestDate;

  final String? fromStore; // e.g. origin of the stock
  final String? toStore; // e.g. destination for transfer or dispense
  final String note;
  final bool isSubmitting;

  final List<IssueRecord> issuedRecords;
  final IssueRecord? selectedIssue;

  IssueFormState({
    this.type = IssueType.dispense, // ✅ Default now matches expected workflow
    DateTime? requestDate,
    this.fromStore,
    this.toStore,
    this.note = '',
    this.isSubmitting = false,
    this.issuedRecords = const [],
    this.selectedIssue,
  }) : requestDate = requestDate ?? DateTime.now();

  IssueFormState copyWith({
    IssueType? type,
    DateTime? requestDate,
    String? fromStore,
    String? toStore,
    String? note,
    bool? isSubmitting,
    List<IssueRecord>? issuedRecords,
    IssueRecord? selectedIssue,
  }) {
    return IssueFormState(
      type: type ?? this.type,
      requestDate: requestDate ?? this.requestDate,
      fromStore: fromStore ?? this.fromStore,
      toStore: toStore ?? this.toStore,
      note: note ?? this.note,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      issuedRecords: issuedRecords ?? this.issuedRecords,
      selectedIssue: selectedIssue ?? this.selectedIssue,
    );
  }
}
