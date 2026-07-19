// lib/features/health_metrics/widgets/health_metrics_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_picker.dart';
import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_card.dart';

import '../models/health_metric_entry.dart';
import '../models/health_metric_type.dart';
import '../providers/health_metrics_providers.dart';
import 'health_metric_entry_dialog.dart';
import 'health_metric_history_screen.dart';
import 'health_metric_ui.dart';

const List<HealthMetricType> _vitalMetricOrder = [
  HealthMetricType.bloodPressure,
  HealthMetricType.pulse,
  HealthMetricType.oxygenSaturation,
  HealthMetricType.respiratoryRate,
];

const List<HealthMetricType> _otherMetricOrder = [
  HealthMetricType.bloodGlucose,
  HealthMetricType.temperature,
];

class HealthMetricsDashboardScreen extends ConsumerStatefulWidget {
  const HealthMetricsDashboardScreen({
    super.key,
    this.initialPatient,
    this.patientPickerContactId,
  });

  final PatientProfile? initialPatient;
  final String? patientPickerContactId;

  @override
  ConsumerState<HealthMetricsDashboardScreen> createState() {
    return _HealthMetricsDashboardScreenState();
  }
}

class _HealthMetricsDashboardScreenState
    extends ConsumerState<HealthMetricsDashboardScreen> {
  PatientProfile? _selectedPatient;
  bool _isSelectingPatient = false;

  @override
  void initState() {
    super.initState();
    _selectedPatient = widget.initialPatient;
  }

  @override
  void didUpdateWidget(covariant HealthMetricsDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldPatientId = oldWidget.initialPatient?.patientId;
    final newPatientId = widget.initialPatient?.patientId;

    if (oldPatientId != newPatientId) {
      _selectedPatient = widget.initialPatient;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPatient = _selectedPatient;

    return AppPage(
      title: 'Health Metrics',
      showBack: true,
      maxWidth: AppLayout.contentMaxWidth,
      padding: AppLayout.pagePadding,
      actions: [
        if (selectedPatient != null)
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(
                healthMetricEntriesProvider(_metricsQueryFor(selectedPatient)),
              );
            },
            icon: const Icon(Icons.refresh),
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PatientSummaryCard(
            patient: selectedPatient,
            onSelectPatient: _isSelectingPatient ? null : _selectPatient,
          ),
          const SizedBox(height: AppShape.gap14),
          if (selectedPatient == null)
            const _NoPatientSelectedCard()
          else
            _PatientMetricsSection(
              key: ValueKey(selectedPatient.patientId),
              patient: selectedPatient,
            ),
        ],
      ),
    );
  }

  Future<void> _selectPatient() async {
    if (_isSelectingPatient) return;

    setState(() {
      _isSelectingPatient = true;
    });

    try {
      final selected = await showDialog<PatientProfile>(
        context: context,
        builder: (_) => PatientPickerDialog(
          contactId: _normalisedContactId(widget.patientPickerContactId),
        ),
      );

      if (!mounted || selected == null) return;
      if (selected.patientId == _selectedPatient?.patientId) return;

      setState(() {
        _selectedPatient = selected;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSelectingPatient = false;
        });
      }
    }
  }
}

class _PatientMetricsSection extends ConsumerWidget {
  const _PatientMetricsSection({super.key, required this.patient});

  final PatientProfile patient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = _metricsQueryFor(patient);

    final metricsAsync = ref.watch(healthMetricEntriesProvider(query));

    return metricsAsync.when(
      loading: () => const _MetricsLoadingCard(),
      error: (error, _) => _MetricsErrorCard(
        error: error,
        onRetry: () {
          ref.invalidate(healthMetricEntriesProvider(query));
        },
      ),
      data: (metrics) => _MetricsDashboard(
        patient: patient,
        metrics: metrics,
        onView: (type) => _openHistory(context, type: type),
        onAdd: (type) => _recordMetric(context, ref, type: type, query: query),
      ),
    );
  }

  Future<void> _openHistory(
    BuildContext context, {
    required HealthMetricType type,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HealthMetricHistoryScreen(patient: patient, type: type),
      ),
    );
  }

  Future<void> _recordMetric(
    BuildContext context,
    WidgetRef ref, {
    required HealthMetricType type,
    required HealthMetricEntriesQuery query,
  }) async {
    final input = await HealthMetricEntryDialog.show(
      context,
      patientId: patient.patientId,
      patientName: patient.fullName,
      type: type,
    );

    if (input == null || !context.mounted) {
      return;
    }

    try {
      final service = ref.read(healthMetricsServiceProvider);

      await service.createMetric(input);

      ref.invalidate(healthMetricEntriesProvider(query));

      ref.invalidate(
        healthMetricEntriesProvider(
          HealthMetricEntriesQuery(
            patientId: patient.patientId,
            type: type,
            isActive: true,
            page: 1,
            perPage: 100,
          ),
        ),
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${type.label} recorded for '
            '${patient.fullName}.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

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
}

class _PatientSummaryCard extends StatelessWidget {
  const _PatientSummaryCard({
    required this.patient,
    required this.onSelectPatient,
  });

  final PatientProfile? patient;
  final VoidCallback? onSelectPatient;

  @override
  Widget build(BuildContext context) {
    final selectedPatient = patient;
    final theme = Theme.of(context);

    if (selectedPatient == null) {
      return AppCard(
        title: 'Patient Profile',
        icon: Icons.person_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select the person whose health '
              'measurements you want to view.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppShape.gap12),
            FilledButton.icon(
              onPressed: onSelectPatient,
              icon: const Icon(Icons.person_search_outlined),
              label: const Text('Select Profile'),
            ),
          ],
        ),
      );
    }

    final dobLabel = _formatDateOfBirth(selectedPatient.dob);

    final age = _calculateAge(selectedPatient.dob);

    final gender = _genderLabel(selectedPatient.gender);

    final relationship = _relationshipLabel(selectedPatient.relationship);

    return AppCard(
      title: 'Patient Profile',
      icon: Icons.account_circle_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  selectedPatient.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppShape.gap6),
              Tooltip(
                message: 'Switch patient profile',
                child: IconButton(
                  onPressed: onSelectPatient,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  iconSize: 19,
                  icon: const Icon(Icons.switch_account_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppShape.gap10),
          Wrap(
            spacing: AppShape.gap10,
            runSpacing: AppShape.gap10,
            children: [
              _DetailChip(
                icon: Icons.badge_outlined,
                label: 'Patient No ${selectedPatient.patientId}',
              ),
              if (relationship != null)
                _DetailChip(
                  icon: Icons.family_restroom_outlined,
                  label: relationship,
                ),
              if (age != null)
                _DetailChip(icon: Icons.cake_outlined, label: '$age years'),
              if (dobLabel != null)
                _DetailChip(
                  icon: Icons.calendar_today_outlined,
                  label: 'DOB $dobLabel',
                ),
              if (gender != null)
                _DetailChip(icon: Icons.person_outline, label: gender),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoPatientSelectedCard extends StatelessWidget {
  const _NoPatientSelectedCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'No Profile Selected',
      icon: Icons.info_outline,
      child: Text(
        'Select a patient profile before recording or viewing health measurements.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MetricsLoadingCard extends StatelessWidget {
  const _MetricsLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      title: 'Measurements',
      icon: Icons.monitor_heart_outlined,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _MetricsErrorCard extends StatelessWidget {
  const _MetricsErrorCard({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Could not load measurements',
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

class _MetricsDashboard extends StatelessWidget {
  const _MetricsDashboard({
    required this.patient,
    required this.metrics,
    required this.onView,
    required this.onAdd,
  });

  final PatientProfile patient;
  final List<HealthMetricEntry> metrics;
  final ValueChanged<HealthMetricType> onView;
  final ValueChanged<HealthMetricType> onAdd;

  @override
  Widget build(BuildContext context) {
    final latestByType = _latestByType(metrics);

    final latestHeight = latestByType[HealthMetricType.height];

    final latestWeight = latestByType[HealthMetricType.weight];

    final bmi = _calculateBmi(height: latestHeight, weight: latestWeight);

    final age = _calculateAge(patient.dob);

    final measurementRange = _measurementDateRange(metrics);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PatientHealthSummaryCard(
          patient: patient,
          metrics: metrics,
          latestByType: latestByType,
          bmi: bmi,
          patientAge: age,
          measurementRange: measurementRange,
        ),
        const SizedBox(height: AppShape.gap14),
        _MetricSection(
          title: 'Vital Signs',
          icon: Icons.monitor_heart_outlined,
          child: _StandardMetricsGrid(
            types: _vitalMetricOrder,
            latestByType: latestByType,
            onView: onView,
            onAdd: onAdd,
          ),
        ),
        const SizedBox(height: AppShape.gap14),
        _MetricSection(
          title: 'Body Measurements',
          icon: Icons.accessibility_new_outlined,
          child: _BodyMeasurementsGrid(
            height: latestHeight,
            weight: latestWeight,
            waist: latestByType[HealthMetricType.waistCircumference],
            bmi: bmi,
            patientAge: age,
            onView: onView,
            onAdd: onAdd,
          ),
        ),
        const SizedBox(height: AppShape.gap14),
        _MetricSection(
          title: 'Other Measurements',
          icon: Icons.science_outlined,
          child: _StandardMetricsGrid(
            types: _otherMetricOrder,
            latestByType: latestByType,
            onView: onView,
            onAdd: onAdd,
          ),
        ),
      ],
    );
  }

  static Map<HealthMetricType, HealthMetricEntry> _latestByType(
    List<HealthMetricEntry> metrics,
  ) {
    final output = <HealthMetricType, HealthMetricEntry>{};

    for (final metric in metrics) {
      final current = output[metric.type];

      if (current == null || metric.recordedAt.isAfter(current.recordedAt)) {
        output[metric.type] = metric;
      }
    }

    return output;
  }
}

class _PatientHealthSummaryCard extends StatelessWidget {
  const _PatientHealthSummaryCard({
    required this.patient,
    required this.metrics,
    required this.latestByType,
    required this.bmi,
    required this.patientAge,
    required this.measurementRange,
  });

  final PatientProfile patient;
  final List<HealthMetricEntry> metrics;
  final Map<HealthMetricType, HealthMetricEntry> latestByType;
  final double? bmi;
  final int? patientAge;
  final DateTimeRange? measurementRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (metrics.isEmpty) {
      return AppCard(
        title: 'Health Summary',
        icon: Icons.summarize_outlined,
        child: Text(
          'No measurements recorded yet.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    final summary = _buildPatientSummary(
      patient: patient,
      latestByType: latestByType,
      bmi: bmi,
      patientAge: patientAge,
    );

    return AppCard(
      title: 'Health Summary',
      icon: Icons.summarize_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: AppShape.gap10),
          Wrap(
            spacing: AppShape.gap8,
            runSpacing: AppShape.gap8,
            children: [
              _DetailChip(
                icon: Icons.format_list_numbered,
                label:
                    '${metrics.length} reading'
                    '${metrics.length == 1 ? '' : 's'}',
              ),
              if (measurementRange != null)
                _DetailChip(
                  icon: Icons.date_range_outlined,
                  label: _measurementRangeLabel(measurementRange!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricSection extends StatelessWidget {
  const _MetricSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: AppShape.gap10),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppShape.gap10),
        child,
      ],
    );
  }
}

class _StandardMetricsGrid extends StatelessWidget {
  const _StandardMetricsGrid({
    required this.types,
    required this.latestByType,
    required this.onView,
    required this.onAdd,
  });

  final List<HealthMetricType> types;

  final Map<HealthMetricType, HealthMetricEntry> latestByType;

  final ValueChanged<HealthMetricType> onView;
  final ValueChanged<HealthMetricType> onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _standardTileWidth(constraints.maxWidth);

        return Wrap(
          spacing: AppShape.gap12,
          runSpacing: AppShape.gap12,
          children: [
            for (final type in types)
              SizedBox(
                width: width,
                child: _HealthMetricCard(
                  type: type,
                  latest: latestByType[type],
                  onView: () => onView(type),
                  onAdd: () => onAdd(type),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BodyMeasurementsGrid extends StatelessWidget {
  const _BodyMeasurementsGrid({
    required this.height,
    required this.weight,
    required this.waist,
    required this.bmi,
    required this.patientAge,
    required this.onView,
    required this.onAdd,
  });

  final HealthMetricEntry? height;
  final HealthMetricEntry? weight;
  final HealthMetricEntry? waist;
  final double? bmi;
  final int? patientAge;

  final ValueChanged<HealthMetricType> onView;
  final ValueChanged<HealthMetricType> onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _bodyTileWidth(constraints.maxWidth);

        return Wrap(
          spacing: AppShape.gap12,
          runSpacing: AppShape.gap12,
          children: [
            SizedBox(
              width: width,
              child: _HealthMetricCard(
                type: HealthMetricType.height,
                latest: height,
                onView: () => onView(HealthMetricType.height),
                onAdd: () => onAdd(HealthMetricType.height),
              ),
            ),
            SizedBox(
              width: width,
              child: _HealthMetricCard(
                type: HealthMetricType.weight,
                latest: weight,
                onView: () => onView(HealthMetricType.weight),
                onAdd: () => onAdd(HealthMetricType.weight),
              ),
            ),
            SizedBox(
              width: width,
              child: _BmiCard(
                bmi: bmi,
                patientAge: patientAge,
                height: height,
                weight: weight,
                onRecordMissingMetric: () {
                  if (height == null) {
                    onAdd(HealthMetricType.height);
                    return;
                  }

                  if (weight == null) {
                    onAdd(HealthMetricType.weight);
                  }
                },
              ),
            ),
            SizedBox(
              width: width,
              child: _HealthMetricCard(
                type: HealthMetricType.waistCircumference,
                latest: waist,
                onView: () => onView(HealthMetricType.waistCircumference),
                onAdd: () => onAdd(HealthMetricType.waistCircumference),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HealthMetricCard extends StatelessWidget {
  const _HealthMetricCard({
    required this.type,
    required this.latest,
    required this.onView,
    required this.onAdd,
  });

  final HealthMetricType type;
  final HealthMetricEntry? latest;
  final VoidCallback onView;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = latest;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppShape.gap14,
            top: AppShape.gap14,
            bottom: AppShape.gap14,
            right: AppShape.gap6,
          ),
          child: Row(
            children: [
              Icon(healthMetricIcon(type), size: 28),
              const SizedBox(width: AppShape.gap12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (current == null)
                      Text(
                        'No reading yet • Tap to view',
                        style: theme.textTheme.bodySmall,
                      )
                    else ...[
                      Text(
                        current.displayValue,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatHealthMetricDateTime(current.recordedAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Record ${type.label}',
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _BmiCard extends StatelessWidget {
  const _BmiCard({
    required this.bmi,
    required this.patientAge,
    required this.height,
    required this.weight,
    required this.onRecordMissingMetric,
  });

  final double? bmi;
  final int? patientAge;
  final HealthMetricEntry? height;
  final HealthMetricEntry? weight;
  final VoidCallback onRecordMissingMetric;

  bool get _hasRequiredMeasurements {
    return height != null && weight != null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentBmi = bmi;

    final adultCategory = currentBmi == null || patientAge == null
        ? null
        : patientAge! >= 18
        ? _adultBmiCategory(currentBmi)
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: _hasRequiredMeasurements ? null : onRecordMissingMetric,
        child: Padding(
          padding: const EdgeInsets.all(AppShape.gap14),
          child: Row(
            children: [
              const Icon(Icons.calculate_outlined, size: 28),
              const SizedBox(width: AppShape.gap12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BMI',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (currentBmi == null)
                      Text(
                        _missingBmiMessage(height: height, weight: weight),
                        style: theme.textTheme.bodySmall,
                      )
                    else ...[
                      Text(
                        '${currentBmi.toStringAsFixed(1)} '
                        'kg/m²',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        adultCategory == null
                            ? 'Calculated from latest '
                                  'height and weight'
                            : '$adultCategory • Calculated '
                                  'from latest readings',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (!_hasRequiredMeasurements)
                const Icon(Icons.add_circle_outline)
              else
                const Icon(Icons.functions),
            ],
          ),
        ),
      ),
    );
  }
}

String _buildPatientSummary({
  required PatientProfile patient,
  required Map<HealthMetricType, HealthMetricEntry> latestByType,
  required double? bmi,
  required int? patientAge,
}) {
  final sections = <String>[];

  final profile = [
    if (patientAge != null) '$patientAge years',
    _genderLabel(patient.gender),
  ].whereType<String>().join(', ');

  if (profile.isNotEmpty) {
    sections.add(profile);
  }

  final vitals = <String>[
    if (latestByType[HealthMetricType.bloodPressure] case final reading?)
      'BP ${reading.displayValue}',
    if (latestByType[HealthMetricType.pulse] case final reading?)
      'pulse ${reading.displayValue}',
    if (latestByType[HealthMetricType.oxygenSaturation] case final reading?)
      'SpO₂ ${reading.displayValue}',
    if (latestByType[HealthMetricType.respiratoryRate] case final reading?)
      'RR ${reading.displayValue}',
    if (latestByType[HealthMetricType.temperature] case final reading?)
      'temperature ${reading.displayValue}',
  ];

  if (vitals.isNotEmpty) {
    sections.add(_joinSummaryItems(vitals));
  }

  final bodyMeasurements = <String>[
    if (latestByType[HealthMetricType.weight] case final reading?)
      'weight ${reading.displayValue}',
    if (latestByType[HealthMetricType.height] case final reading?)
      'height ${reading.displayValue}',
    if (bmi != null) _bmiSummary(bmi, patientAge),
  ];

  if (bodyMeasurements.isNotEmpty) {
    sections.add(_joinSummaryItems(bodyMeasurements));
  }

  final glucose = latestByType[HealthMetricType.bloodGlucose];

  if (glucose != null) {
    sections.add('glucose ${glucose.displayValue}');
  }

  return sections.isEmpty ? 'No summary available.' : '${sections.join('. ')}.';
}

String _bmiSummary(double bmi, int? patientAge) {
  final value = bmi.toStringAsFixed(1);

  if (patientAge == null || patientAge < 18) {
    return 'BMI $value';
  }

  return 'BMI $value '
      '(${_adultBmiCategory(bmi).toLowerCase()})';
}

String _joinSummaryItems(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  if (items.length == 2) return '${items.first} and ${items.last}';

  return '${items.take(items.length - 1).join(', ')}, and ${items.last}';
}

String? _normalisedContactId(String? value) {
  final contactId = value?.trim();

  if (contactId == null || contactId.isEmpty) {
    return null;
  }

  return contactId;
}

HealthMetricEntriesQuery _metricsQueryFor(PatientProfile patient) {
  return HealthMetricEntriesQuery(
    patientId: patient.patientId,
    isActive: true,
    page: 1,
    perPage: 100,
  );
}

double _standardTileWidth(double availableWidth) {
  if (availableWidth >= 600) {
    return (availableWidth - AppShape.gap12) / 2;
  }

  return availableWidth;
}

double _bodyTileWidth(double availableWidth) {
  if (availableWidth >= 960) {
    return (availableWidth - (AppShape.gap12 * 3)) / 4;
  }

  if (availableWidth >= 680) {
    return (availableWidth - AppShape.gap12) / 2;
  }

  return availableWidth;
}

DateTimeRange? _measurementDateRange(List<HealthMetricEntry> metrics) {
  if (metrics.isEmpty) {
    return null;
  }

  var first = metrics.first.recordedAt;
  var latest = metrics.first.recordedAt;

  for (final metric in metrics.skip(1)) {
    final recordedAt = metric.recordedAt;

    if (recordedAt.isBefore(first)) {
      first = recordedAt;
    }

    if (recordedAt.isAfter(latest)) {
      latest = recordedAt;
    }
  }

  return DateTimeRange(start: first, end: latest);
}

String _measurementRangeLabel(DateTimeRange range) {
  final first = formatHealthMetricDate(range.start);

  final latest = formatHealthMetricDate(range.end);

  if (first == latest) {
    return 'First and latest: $first';
  }

  return '$first – $latest';
}

double? _calculateBmi({
  required HealthMetricEntry? height,
  required HealthMetricEntry? weight,
}) {
  if (height == null || weight == null) {
    return null;
  }

  final heightCm = height.primaryValue;
  final weightKg = weight.primaryValue;

  if (heightCm <= 0 || weightKg <= 0) {
    return null;
  }

  final heightMetres = heightCm / 100;

  if (heightMetres <= 0) {
    return null;
  }

  final bmi = weightKg / (heightMetres * heightMetres);

  if (!bmi.isFinite || bmi <= 0) {
    return null;
  }

  return bmi;
}

String _missingBmiMessage({
  required HealthMetricEntry? height,
  required HealthMetricEntry? weight,
}) {
  if (height == null && weight == null) {
    return 'Record height and weight to calculate';
  }

  if (height == null) {
    return 'Record height to calculate';
  }

  if (weight == null) {
    return 'Record weight to calculate';
  }

  return 'BMI could not be calculated';
}

String _adultBmiCategory(double bmi) {
  if (bmi < 18.5) {
    return 'Underweight';
  }

  if (bmi < 25) {
    return 'Healthy range';
  }

  if (bmi < 30) {
    return 'Overweight';
  }

  return 'Obesity range';
}

String _errorMessage(Object error) {
  final text = error.toString().trim();

  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }

  return text;
}

int? _calculateAge(String? rawDob) {
  final dob = _parseDate(rawDob);

  if (dob == null) {
    return null;
  }

  final today = DateTime.now();
  var age = today.year - dob.year;

  final birthdayHasOccurred =
      today.month > dob.month ||
      (today.month == dob.month && today.day >= dob.day);

  if (!birthdayHasOccurred) {
    age--;
  }

  return age >= 0 ? age : null;
}

String? _formatDateOfBirth(String? rawDob) {
  final dob = _parseDate(rawDob);

  if (dob == null) {
    return null;
  }

  final day = dob.day.toString().padLeft(2, '0');

  final month = dob.month.toString().padLeft(2, '0');

  return '$day/$month/${dob.year}';
}

DateTime? _parseDate(String? value) {
  final raw = value?.trim();

  if (raw == null || raw.isEmpty) {
    return null;
  }

  return DateTime.tryParse(raw);
}

String? _genderLabel(PatientGender? gender) {
  switch (gender) {
    case PatientGender.male:
      return 'Male';

    case PatientGender.female:
      return 'Female';

    case PatientGender.other:
      return 'Other';

    case PatientGender.unknown:
    case null:
      return null;
  }
}

String? _relationshipLabel(PatientContactRelationship? relationship) {
  switch (relationship) {
    case PatientContactRelationship.self:
      return 'Self';

    case PatientContactRelationship.child:
      return 'Child';

    case PatientContactRelationship.spouse:
      return 'Spouse';

    case PatientContactRelationship.parent:
      return 'Parent';

    case PatientContactRelationship.guardian:
      return 'Guardian';

    case PatientContactRelationship.insurance:
      return 'Insurance';

    case PatientContactRelationship.other:
      return 'Other';

    case null:
      return null;
  }
}
