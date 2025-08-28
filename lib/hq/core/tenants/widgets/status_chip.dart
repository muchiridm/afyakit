// lib/hq/tenants/widgets/status_chip.dart
import 'package:flutter/material.dart';
import 'package:afyakit/hq/core/tenants/extensions/tenant_status_x.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.compact = false});

  final TenantStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Colors per state
    final Color bg;
    final Color fg;
    switch (status) {
      case TenantStatus.active:
        bg = scheme.primaryContainer;
        fg = scheme.onPrimaryContainer;
        break;
      case TenantStatus.suspended:
        bg = scheme.tertiaryContainer;
        fg = scheme.onTertiaryContainer;
        break;
      case TenantStatus.deleted:
        bg = scheme.errorContainer;
        fg = scheme.onErrorContainer;
        break;
    }

    // Capitalized label from enum's wire value
    final wire = status.value; // 'active' | 'suspended' | 'deleted'
    final label = wire.isEmpty
        ? wire
        : '${wire[0].toUpperCase()}${wire.substring(1)}';

    return Chip(
      label: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
          letterSpacing: .2,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: bg,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 0)
          : null,
    );
  }
}
