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
  // partial variants should come before the final ones
  partiallyDisposed,
  disposed,
  partiallyDispensed,
  dispensed,
}

extension IssueStatusX on IssueStatus {
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
      case IssueStatus.partiallyDisposed:
        return 'Partially disposed';
      case IssueStatus.disposed:
        return 'Disposed';
      case IssueStatus.partiallyDispensed:
        return 'Partially dispensed';
      case IssueStatus.dispensed:
        return 'Dispensed';
    }
  }

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
      case IssueStatus.partiallyDisposed:
        return Colors.deepOrange; // up to you
      case IssueStatus.disposed:
        return Colors.red;
      case IssueStatus.partiallyDispensed:
        return Colors.amber;
      case IssueStatus.dispensed:
        return Colors.purple;
    }
  }

  bool get isFinal =>
      this == IssueStatus.rejected ||
      this == IssueStatus.issued ||
      this == IssueStatus.received ||
      this == IssueStatus.cancelled ||
      this == IssueStatus.partiallyDisposed || // 👈 final
      this == IssueStatus.disposed ||
      this == IssueStatus.partiallyDispensed || // 👈 final
      this == IssueStatus.dispensed;

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
      case 'partiallydisposed':
      case 'partially_disposed':
        return IssueStatus.partiallyDisposed;
      case 'disposed':
        return IssueStatus.disposed;
      case 'partiallydispensed':
      case 'partially_dispensed':
        return IssueStatus.partiallyDispensed;
      case 'dispensed':
        return IssueStatus.dispensed;
      default:
        return IssueStatus.pending;
    }
  }
}
