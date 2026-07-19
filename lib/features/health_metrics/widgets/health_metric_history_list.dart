// lib/features/health_metrics/widgets/health_metric_history_list.dart

import 'package:flutter/material.dart';

import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_card.dart';

import '../models/health_metric_entry.dart';
import '../models/health_metric_type.dart';
import 'health_metric_ui.dart';

class HealthMetricHistoryList extends StatelessWidget {
  const HealthMetricHistoryList({
    super.key,
    required this.type,
    required this.entries,
  });

  final HealthMetricType type;
  final List<HealthMetricEntry> entries;

  @override
  Widget build(BuildContext context) {
    final orderedEntries = [...entries]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    if (orderedEntries.isEmpty) {
      return AppCard(
        title: 'History',
        icon: Icons.history,
        child: Text(
          'No ${type.label.toLowerCase()} readings '
          'have been recorded yet.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return _DesktopHistoryTable(entries: orderedEntries);
        }

        return _MobileHistoryList(entries: orderedEntries);
      },
    );
  }
}

class _DesktopHistoryTable extends StatelessWidget {
  const _DesktopHistoryTable({required this.entries});

  final List<HealthMetricEntry> entries;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'History',
      icon: Icons.history,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Time')),
            DataColumn(label: Text('Reading')),
            DataColumn(label: Text('Context')),
            DataColumn(label: Text('Notes')),
          ],
          rows: [
            for (final entry in entries)
              DataRow(
                cells: [
                  DataCell(Text(formatHealthMetricDate(entry.recordedAt))),
                  DataCell(Text(formatHealthMetricTime(entry.recordedAt))),
                  DataCell(
                    Text(
                      entry.displayValue,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataCell(Text(healthMetricContextLabel(entry.context))),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        nullableHealthMetricText(entry.notes),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MobileHistoryList extends StatelessWidget {
  const _MobileHistoryList({required this.entries});

  final List<HealthMetricEntry> entries;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'History',
      icon: Icons.history,
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            _MobileHistoryEntry(entry: entries[index]),
            if (index < entries.length - 1)
              const Divider(height: AppShape.gap24),
          ],
        ],
      ),
    );
  }
}

class _MobileHistoryEntry extends StatelessWidget {
  const _MobileHistoryEntry({required this.entry});

  final HealthMetricEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contextLabel = healthMetricContextLabel(entry.context);

    final notes = nullableHealthMetricText(entry.notes);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.history_toggle_off_outlined, size: 22),
        ),
        const SizedBox(width: AppShape.gap12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.displayValue,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                formatHealthMetricDateTime(entry.recordedAt),
                style: theme.textTheme.bodySmall,
              ),
              if (contextLabel != '—') ...[
                const SizedBox(height: 3),
                Text(contextLabel, style: theme.textTheme.bodySmall),
              ],
              if (notes != '—') ...[
                const SizedBox(height: 6),
                Text(notes, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
