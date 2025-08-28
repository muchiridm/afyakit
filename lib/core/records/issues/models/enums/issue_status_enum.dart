// file: lib/features/src/issues/utils/issue_status_enum.dart

import 'package:flutter/material.dart';

enum IssueStatus {
  pending,
  approved,
  rejected,
  issued,
  received,
  cancelled,
  disposed,
  dispensed,
}

Color getIssueStatusColor(IssueStatus status) {
  switch (status) {
    case IssueStatus.pending:
      return Colors.orange;
    case IssueStatus.approved:
      return Colors.green;
    case IssueStatus.rejected:
      return Colors.redAccent;
    case IssueStatus.issued:
      return Colors.blue;
    case IssueStatus.received:
      return Colors.teal;
    case IssueStatus.cancelled:
      return Colors.grey;
    case IssueStatus.disposed:
      return Colors.red;
    case IssueStatus.dispensed:
      return Colors.purple;
  }
}
