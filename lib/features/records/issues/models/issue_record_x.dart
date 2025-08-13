import 'package:afyakit/features/records/issues/models/issue_record.dart';

extension IssueRecordX on IssueRecord {
  String get fromStoreName => fromStore; // already a name
  String get toStoreName => toStore; // already a name
}
