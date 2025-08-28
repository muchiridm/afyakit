import 'package:flutter/material.dart';

class IssueActionButton {
  final String label;
  final IconData icon;
  final Color color;
  final void Function(BuildContext context) onPressed;

  IssueActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });
}
