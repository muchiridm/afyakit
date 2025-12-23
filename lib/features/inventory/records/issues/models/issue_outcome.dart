// lib/core/records/issues/models/issue_outcome.dart
import 'package:afyakit/features/inventory/records/issues/models/issue_record.dart';

class IssueOutcome {
  /// Updated issue record (with new status/timestamps/actor)
  final IssueRecord record;

  /// Short, UX-friendly message → goes to snackbar and to Firestore message
  final String message;

  /// Optional long message for partial success (failed lines, reasons…)
  /// Controller can decide to show this in a dialog, or just log it.
  final String? details;

  const IssueOutcome(this.record, this.message, {this.details});
}
