// lib/features/retail/shared/sales_doc/date_pill.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  String _compactDate(DateTime? d) {
    if (d == null) return '-';
    return DateFormat('MMM d, y').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final DateTime? d = date;
    final String text = _compactDate(d);

    final bool canPick = enabled && onPick != null;
    final bool canClear =
        enabled && onClear != null && (d != null || showClearWhenNull);

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $text',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
            ),
          ),
          if (canClear) ...<Widget>[
            const SizedBox(width: 2),
            IconButton(
              tooltip: 'Clear $label',
              icon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: onClear,
            ),
          ],
          if (canPick) ...<Widget>[
            const SizedBox(width: 2),
            IconButton(
              tooltip: 'Pick $label',
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: onPick,
            ),
          ],
        ],
      ),
    );
  }
}
