// lib/features/issues/models/enums/issue_action_color.dart

import 'package:flutter/material.dart';

enum IssueAction { approve, reject, cancel, issue, receive, dispose, dispense }

Color getIssueActionColor(IssueAction action) {
  switch (action) {
    case IssueAction.approve:
      return Colors.green;
    case IssueAction.reject:
      return Colors.redAccent;
    case IssueAction.cancel:
      return Colors.orange;
    case IssueAction.issue:
      return Colors.blue;
    case IssueAction.receive:
      return Colors.teal;
    case IssueAction.dispose:
      return Colors.redAccent;
    case IssueAction.dispense:
      return Colors.purple;
  }
}
