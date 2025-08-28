import 'package:afyakit/core/records/issues/models/enums/issue_type_enum.dart';
import 'package:flutter/material.dart';

extension IssueTypeX on IssueType {
  /// Converts a string to IssueType enum, defaults to `transfer` if unknown or null
  static IssueType fromString(String? value) {
    if (value == null) return IssueType.transfer;

    return IssueType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => IssueType.transfer,
    );
  }

  /// Human-friendly label
  String get label => switch (this) {
    IssueType.transfer => 'Transfer',
    IssueType.dispense => 'Dispense',
    IssueType.dispose => 'Dispose',
  };

  /// Icon representation
  IconData get icon => switch (this) {
    IssueType.transfer => Icons.compare_arrows,
    IssueType.dispense => Icons.medical_services,
    IssueType.dispose => Icons.delete_forever,
  };

  /// Emoji representation – useful for status chips, summaries, logs etc.
  String get emoji => switch (this) {
    IssueType.transfer => '🔁',
    IssueType.dispense => '💊',
    IssueType.dispose => '🗑️',
  };
}
