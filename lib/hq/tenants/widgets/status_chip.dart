// lib/hq/tenants/widgets/status_chip.dart
import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    return Chip(
      label: Text(isActive ? 'Active' : 'Suspended'),
      backgroundColor: isActive
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.errorContainer,
    );
  }
}
