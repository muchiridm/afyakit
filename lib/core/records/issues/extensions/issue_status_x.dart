// lib/core/records/issues/models/enums/issue_status_x.dart
import 'package:flutter/material.dart';

/// Canonical lifecycle states for an Issue.
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

extension IssueStatusX on IssueStatus {
  /// Human-friendly label.
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

  /// UI color for the status.
  Color get color {
    switch (this) {
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

  /// Whether this status is terminal in the workflow.
  bool get isFinal =>
      this == IssueStatus.rejected ||
      this == IssueStatus.issued ||
      this == IssueStatus.received ||
      this == IssueStatus.cancelled ||
      this == IssueStatus.disposed ||
      this == IssueStatus.dispensed;

  /// Robust string parser (accepts "approved", "IssueStatus.approved",
  /// case-insensitive; defaults to `pending`).
  static IssueStatus fromString(String value) {
    final v = value.trim().toLowerCase();
    final key = v.contains('.') ? v.split('.').last : v;
    switch (key) {
      case 'pending':
        return IssueStatus.pending;
      case 'approved':
        return IssueStatus.approved;
      case 'rejected':
        return IssueStatus.rejected;
      case 'issued':
        return IssueStatus.issued;
      case 'received':
        return IssueStatus.received;
      case 'cancelled':
        return IssueStatus.cancelled;
      case 'disposed':
        return IssueStatus.disposed;
      case 'dispensed':
        return IssueStatus.dispensed;
      default:
        return IssueStatus.pending;
    }
  }
}
