// lib/features/health_metrics/widgets/health_metric_chart.dart

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:afyakit/shared/theme/app_shape.dart';

import '../models/health_metric_entry.dart';
import '../models/health_metric_type.dart';
import 'health_metric_ui.dart';

class HealthMetricChart extends StatefulWidget {
  const HealthMetricChart({
    super.key,
    required this.type,
    required this.entries,
    this.initiallyExpanded = false,
  });

  final HealthMetricType type;
  final List<HealthMetricEntry> entries;
  final bool initiallyExpanded;

  @override
  State<HealthMetricChart> createState() {
    return _HealthMetricChartState();
  }
}

class _HealthMetricChartState extends State<HealthMetricChart> {
  late bool _isExpanded;

  HealthMetricType get _type => widget.type;

  bool get _isBloodPressure {
    return _type == HealthMetricType.bloodPressure;
  }

  List<HealthMetricEntry> get _orderedEntries {
    return [...widget.entries]
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  }

  @override
  void initState() {
    super.initState();

    _isExpanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant HealthMetricChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.type != widget.type) {
      _isExpanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderedEntries = _orderedEntries;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _isExpanded,
            label: _isExpanded ? 'Collapse trend chart' : 'Expand trend chart',
            child: InkWell(
              onTap: _toggleExpanded,
              child: Padding(
                padding: AppShape.cardPad,
                child: Row(
                  children: [
                    const Icon(Icons.show_chart),
                    const SizedBox(width: AppShape.gap10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trend',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _headerSubtitle(orderedEntries.length),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeInOut,
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeIn,
            sizeCurve: Curves.easeInOut,
            crossFadeState: _isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppShape.gap14,
                0,
                AppShape.gap14,
                AppShape.gap14,
              ),
              child: _buildContent(context, orderedEntries),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  Widget _buildContent(BuildContext context, List<HealthMetricEntry> entries) {
    if (entries.isEmpty) {
      return const _EmptyTrendContent();
    }

    if (entries.length == 1) {
      return _SingleReadingContent(type: _type, entry: entries.first);
    }

    final chartData = _HealthMetricChartData.fromEntries(
      type: _type,
      entries: entries,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isBloodPressure) ...[
          const _BloodPressureLegend(),
          const SizedBox(height: AppShape.gap12),
        ],
        SizedBox(
          height: 300,
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppShape.gap10,
              right: AppShape.gap10,
            ),
            child: LineChart(
              _buildLineChartData(context, chartData),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            ),
          ),
        ),
        const SizedBox(height: AppShape.gap10),
        Text(
          _chartDescription(entries.length),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  LineChartData _buildLineChartData(
    BuildContext context,
    _HealthMetricChartData data,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final primaryColor = colorScheme.primary;
    final secondaryColor = colorScheme.tertiary;

    return LineChartData(
      minX: 0,
      maxX: data.maxX,
      minY: data.minY,
      maxY: data.maxY,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: data.yInterval,
        getDrawingHorizontalLine: (_) {
          return FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            strokeWidth: 1,
          );
        },
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant),
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          axisNameWidget: Padding(
            padding: const EdgeInsets.only(bottom: AppShape.gap4),
            child: Text(_type.unit, style: theme.textTheme.bodySmall),
          ),
          axisNameSize: 24,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 48,
            interval: data.yInterval,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                meta: meta,
                space: AppShape.gap8,
                child: Text(
                  _formatAxisNumber(value),
                  style: theme.textTheme.bodySmall,
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 42,
            interval: data.xInterval,
            getTitlesWidget: (value, meta) {
              final index = value.round();

              if (!_shouldShowBottomTitle(
                value: value,
                index: index,
                entryCount: data.entries.length,
              )) {
                return const SizedBox.shrink();
              }

              final entry = data.entries[index];

              return SideTitleWidget(
                meta: meta,
                space: AppShape.gap10,
                child: Text(
                  _formatShortDate(entry.recordedAt),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipBorderRadius: AppShape.tileRadius,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final entryIndex = spot.x.round();

              if (entryIndex < 0 || entryIndex >= data.entries.length) {
                return null;
              }

              final entry = data.entries[entryIndex];

              final label = _seriesLabel(barIndex: spot.barIndex);

              return LineTooltipItem(
                '$label: '
                '${_formatValue(spot.y)} ${_type.unit}\n'
                '${formatHealthMetricDateTime(entry.recordedAt)}',
                TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: data.primarySpots,
          isCurved: false,
          color: primaryColor,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: data.entries.length <= 30),
          belowBarData: BarAreaData(
            show: !_isBloodPressure,
            color: primaryColor.withValues(alpha: 0.10),
          ),
        ),
        if (_isBloodPressure)
          LineChartBarData(
            spots: data.secondarySpots,
            isCurved: false,
            color: secondaryColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: data.entries.length <= 30),
            belowBarData: BarAreaData(show: false),
          ),
      ],
    );
  }

  String _seriesLabel({required int barIndex}) {
    if (!_isBloodPressure) {
      return _type.label;
    }

    return barIndex == 0 ? 'Systolic' : 'Diastolic';
  }

  String _headerSubtitle(int readingCount) {
    if (readingCount == 0) {
      return 'No readings recorded';
    }

    if (readingCount == 1) {
      return '1 reading • Add another to show a trend';
    }

    return '$readingCount readings • Oldest to newest';
  }

  String _chartDescription(int readingCount) {
    if (_isBloodPressure) {
      return '$readingCount blood pressure readings '
          'shown from oldest to newest.';
    }

    return '$readingCount ${_type.label.toLowerCase()} '
        'readings shown from oldest to newest.';
  }
}

class _EmptyTrendContent extends StatelessWidget {
  const _EmptyTrendContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.insights_outlined,
          size: 28,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppShape.gap12),
        Expanded(
          child: Text(
            'Record at least two readings to view a trend.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _SingleReadingContent extends StatelessWidget {
  const _SingleReadingContent({required this.type, required this.entry});

  final HealthMetricType type;
  final HealthMetricEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(healthMetricIcon(type), size: 28),
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
              const SizedBox(height: AppShape.gap4),
              Text(
                formatHealthMetricDateTime(entry.recordedAt),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppShape.gap10),
              Text(
                'Record another reading to start showing '
                'the trend.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BloodPressureLegend extends StatelessWidget {
  const _BloodPressureLegend();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: AppShape.gap14,
      runSpacing: AppShape.gap8,
      children: [
        _LegendItem(color: colorScheme.primary, label: 'Systolic'),
        _LegendItem(color: colorScheme.tertiary, label: 'Diastolic'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppShape.gap6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _HealthMetricChartData {
  const _HealthMetricChartData({
    required this.entries,
    required this.primarySpots,
    required this.secondarySpots,
    required this.minY,
    required this.maxY,
    required this.maxX,
    required this.xInterval,
    required this.yInterval,
  });

  final List<HealthMetricEntry> entries;

  final List<FlSpot> primarySpots;
  final List<FlSpot> secondarySpots;

  final double minY;
  final double maxY;
  final double maxX;

  final double xInterval;
  final double yInterval;

  factory _HealthMetricChartData.fromEntries({
    required HealthMetricType type,
    required List<HealthMetricEntry> entries,
  }) {
    final primarySpots = <FlSpot>[];
    final secondarySpots = <FlSpot>[];
    final allValues = <double>[];

    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final x = index.toDouble();

      primarySpots.add(FlSpot(x, entry.primaryValue));

      allValues.add(entry.primaryValue);

      if (type == HealthMetricType.bloodPressure) {
        final secondaryValue = entry.secondaryValue;

        if (secondaryValue != null) {
          secondarySpots.add(FlSpot(x, secondaryValue));

          allValues.add(secondaryValue);
        }
      }
    }

    final double rawMinY = allValues.reduce(math.min);

    final double rawMaxY = allValues.reduce(math.max);

    final double rawRange = rawMaxY - rawMinY;

    final double fallbackRange = _fallbackRangeFor(type, rawMaxY);

    final double effectiveRange = rawRange > 0 ? rawRange : fallbackRange;

    final double yPadding = math
        .max(effectiveRange * 0.16, _minimumPaddingFor(type))
        .toDouble();

    final double minY = math.max(0.0, rawMinY - yPadding).toDouble();

    final double maxY = rawMaxY + yPadding;

    final double maxX = math.max(1, entries.length - 1).toDouble();

    return _HealthMetricChartData(
      entries: entries,
      primarySpots: primarySpots,
      secondarySpots: secondarySpots,
      minY: minY,
      maxY: maxY,
      maxX: maxX,
      xInterval: _xIntervalFor(entries.length),
      yInterval: _niceInterval(maxY - minY),
    );
  }
}

double _xIntervalFor(int entryCount) {
  if (entryCount <= 6) {
    return 1;
  }

  if (entryCount <= 12) {
    return 2;
  }

  if (entryCount <= 24) {
    return 4;
  }

  return math.max(1, (entryCount / 6).ceil()).toDouble();
}

double _niceInterval(double range) {
  if (!range.isFinite || range <= 0) {
    return 1;
  }

  final roughInterval = range / 5;

  final magnitude = math
      .pow(10, (math.log(roughInterval) / math.ln10).floor())
      .toDouble();

  final normalized = roughInterval / magnitude;

  final double niceNormalized;

  if (normalized <= 1) {
    niceNormalized = 1;
  } else if (normalized <= 2) {
    niceNormalized = 2;
  } else if (normalized <= 5) {
    niceNormalized = 5;
  } else {
    niceNormalized = 10;
  }

  return niceNormalized * magnitude;
}

double _fallbackRangeFor(HealthMetricType type, double value) {
  switch (type) {
    case HealthMetricType.bloodPressure:
      return 40;

    case HealthMetricType.pulse:
      return 20;

    case HealthMetricType.oxygenSaturation:
      return 5;

    case HealthMetricType.respiratoryRate:
      return 6;

    case HealthMetricType.height:
      return 10;

    case HealthMetricType.weight:
      return 10;

    case HealthMetricType.waistCircumference:
      return 10;

    case HealthMetricType.bloodGlucose:
      return math.max(value * 0.2, 2.0).toDouble();

    case HealthMetricType.temperature:
      return 2;
  }
}

double _minimumPaddingFor(HealthMetricType type) {
  switch (type) {
    case HealthMetricType.bloodPressure:
      return 8;

    case HealthMetricType.pulse:
      return 5;

    case HealthMetricType.oxygenSaturation:
      return 1;

    case HealthMetricType.respiratoryRate:
      return 2;

    case HealthMetricType.height:
      return 2;

    case HealthMetricType.weight:
      return 2;

    case HealthMetricType.waistCircumference:
      return 2;

    case HealthMetricType.bloodGlucose:
      return 0.5;

    case HealthMetricType.temperature:
      return 0.5;
  }
}

bool _shouldShowBottomTitle({
  required double value,
  required int index,
  required int entryCount,
}) {
  if (value != index.toDouble()) {
    return false;
  }

  if (index < 0 || index >= entryCount) {
    return false;
  }

  if (index == 0 || index == entryCount - 1) {
    return true;
  }

  final desiredLabels = math.min(6, entryCount);

  final interval = math.max(1, (entryCount / desiredLabels).ceil());

  return index % interval == 0;
}

String _formatShortDate(DateTime value) {
  final local = value.toLocal();

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${local.day}\n'
      '${months[local.month - 1]}';
}

String _formatAxisNumber(double value) {
  if (value.abs() >= 1000 || value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(1);
}

String _formatValue(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(1);
}
