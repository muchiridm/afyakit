// lib/features/retail/shared/sales_doc/date_pill.dart

import 'package:flutter/material.dart';

import 'helpers.dart';

class SalesDocDatePill extends StatelessWidget {
  const SalesDocDatePill({
    super.key,
    required this.label,
    required this.date,
    required this.icon,
    this.onPick,
    this.onClear,
    this.enabled = true,
    this.showClearWhenNull = false,
  });

  final String label;
  final DateTime? date;
  final IconData icon;

  final VoidCallback? onPick;
  final VoidCallback? onClear;

  final bool enabled;
  final bool showClearWhenNull;

  @override
  Widget build(BuildContext context) {
    final d = date;
    final text = d == null ? '-' : formatDocDate(d);

    final canPick = enabled && onPick != null;
    final canClear =
        enabled && onClear != null && (d != null || showClearWhenNull);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text('$label: $text', style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          if (canClear)
            IconButton(
              tooltip: 'Clear $label',
              icon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: onClear,
            ),
          if (canPick)
            IconButton(
              tooltip: 'Pick $label',
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: onPick,
            ),
        ],
      ),
    );
  }
}
