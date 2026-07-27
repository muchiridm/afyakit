// lib/features/health_metrics/widgets/health_metric_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/clinical/profiles/models/profile_models.dart';
import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_card.dart';

import '../models/health_metric_entry.dart';
import '../models/health_metric_type.dart';
import '../providers/health_metrics_providers.dart';
import 'health_metric_chart.dart';
import 'health_metric_entry_dialog.dart';
import 'health_metric_history_list.dart';
import 'health_metric_ui.dart';

class HealthMetricHistoryScreen extends ConsumerWidget {
  const HealthMetricHistoryScreen({
    super.key,
    required this.patient,
    required this.type,
  });

  final Profile patient;
  final HealthMetricType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = _historyQuery();

    final entriesAsync = ref.watch(healthMetricEntriesProvider(query));

    return AppPage(
      title: type.label,
      showBack: true,
      maxWidth: AppLayout.contentMaxWidth,
      padding: AppLayout.pagePadding,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(healthMetricEntriesProvider(query));
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: entriesAsync.when(
        loading: () => const _HistoryLoading(),
        error: (error, _) => _HistoryError(
          error: error,
          onRetry: () {
            ref.invalidate(healthMetricEntriesProvider(query));
          },
        ),
        data: (entries) {
          final newestFirst = [...entries]
            ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

          final latest = newestFirst.isEmpty ? null : newestFirst.first;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HistoryHeader(
                patient: patient,
                type: type,
                latest: latest,
                readingCount: newestFirst.length,
                onRecord: () => _recordMetric(context, ref, query: query),
              ),
              const SizedBox(height: AppShape.gap14),
              HealthMetricChart(type: type, entries: newestFirst),
              const SizedBox(height: AppShape.gap14),
              HealthMetricHistoryList(type: type, entries: newestFirst),
            ],
          );
        },
      ),
    );
  }

  HealthMetricEntriesQuery _historyQuery() {
    return HealthMetricEntriesQuery(
      patientId: patient.profileId,
      type: type,
      isActive: true,
      page: 1,
      perPage: 100,
    );
  }

  Future<void> _recordMetric(
    BuildContext context,
    WidgetRef ref, {
    required HealthMetricEntriesQuery query,
  }) async {
    final input = await HealthMetricEntryDialog.show(
      context,
      patientId: patient.profileId,
      patientName: patient.fullName,
      type: type,
    );

    if (input == null || !context.mounted) {
      return;
    }

    try {
      final service = ref.read(healthMetricsServiceProvider);

      await service.createMetric(input);

      _invalidateHistoryAndDashboard(ref, query: query);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${type.label} recorded for '
            '${patient.fullName}.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save ${type.label}: '
            '${_errorMessage(error)}',
          ),
        ),
      );
    }
  }

  void _invalidateHistoryAndDashboard(
    WidgetRef ref, {
    required HealthMetricEntriesQuery query,
  }) {
    ref.invalidate(healthMetricEntriesProvider(query));

    ref.invalidate(
      healthMetricEntriesProvider(
        HealthMetricEntriesQuery(
          patientId: patient.profileId,
          isActive: true,
          page: 1,
          perPage: 100,
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.patient,
    required this.type,
    required this.latest,
    required this.readingCount,
    required this.onRecord,
  });

  final Profile patient;
  final HealthMetricType type;
  final HealthMetricEntry? latest;
  final int readingCount;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = latest;

    return AppCard(
      title: patient.fullName,
      icon: healthMetricIcon(type),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (current == null)
            Text(
              'No ${type.label.toLowerCase()} '
              'reading has been recorded.',
              style: theme.textTheme.bodyMedium,
            )
          else ...[
            Text('Latest reading', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              current.displayValue,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatHealthMetricDateTime(current.recordedAt),
              style: theme.textTheme.bodySmall,
            ),
            if (_hasText(current.context)) ...[
              const SizedBox(height: 3),
              Text(
                healthMetricContextLabel(current.context),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (_hasText(current.notes)) ...[
              const SizedBox(height: AppShape.gap10),
              Text(current.notes!.trim(), style: theme.textTheme.bodyMedium),
            ],
          ],
          const SizedBox(height: AppShape.gap14),
          Wrap(
            spacing: AppShape.gap12,
            runSpacing: AppShape.gap10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onRecord,
                icon: const Icon(Icons.add),
                label: const Text('Record Reading'),
              ),
              Text(
                '$readingCount reading'
                '${readingCount == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      title: 'Loading history',
      icon: Icons.history,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Could not load history',
      icon: Icons.error_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_errorMessage(error)),
          const SizedBox(height: AppShape.gap12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

bool _hasText(String? value) {
  return value?.trim().isNotEmpty ?? false;
}

String _errorMessage(Object error) {
  final text = error.toString().trim();

  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }

  return text;
}
