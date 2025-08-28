//library: lib/features/issues/models/enums/issue_status_x.dart

import 'package:afyakit/core/records/issues/models/enums/issue_status_enum.dart';

extension IssueStatusX on IssueStatus {
  String get name => toString().split('.').last;

  String get label {
    switch (this) {
      case IssueStatus.pending:
        return 'Pending';
      case IssueStatus.approved:
        return 'Approved';
      case IssueStatus.rejected:
        return 'Rejected';
      case IssueStatus.issued:
        return 'Issued';
      case IssueStatus.received:
        return 'Received';
      case IssueStatus.cancelled:
        return 'Cancelled';
      case IssueStatus.disposed:
        return 'Disposed';
      case IssueStatus.dispensed:
        return 'Dispensed';
    }
  }

  static IssueStatus fromString(String value) {
    return IssueStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => IssueStatus.pending,
    );
  }

  bool get isFinal =>
      this == IssueStatus.rejected ||
      this == IssueStatus.issued ||
      this == IssueStatus.received ||
      this == IssueStatus.cancelled ||
      this == IssueStatus.disposed ||
      this == IssueStatus.dispensed;
}
