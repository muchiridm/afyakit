// lib/core/records/issues/models/view_models/issue_action_button.dart
import 'dart:async';
import 'package:flutter/material.dart';

typedef IssueActionHandler = FutureOr<void> Function(BuildContext);

class IssueActionButton {
  final String label;
  final IconData icon;
  final Color color;

  /// Always awaitable from the UI:  await btn.onPressed(context);
  final IssueActionHandler onPressed;

  /// Accepts a sync or async handler and normalizes it to a Future.
  IssueActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required IssueActionHandler handler, // <-- parameter is *handler*
  }) : onPressed = ((BuildContext ctx) => Future.sync(() => handler(ctx)));

  @override
  String toString() => 'IssueActionButton(label: $label)';
}
