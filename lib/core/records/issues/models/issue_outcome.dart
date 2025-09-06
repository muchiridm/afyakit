// lib/core/records/issues/models/issue_outcome.dart
import 'package:afyakit/core/records/issues/models/issue_record.dart';

class IssueOutcome {
  final IssueRecord record;
  final String message;
  const IssueOutcome(this.record, this.message);
}
