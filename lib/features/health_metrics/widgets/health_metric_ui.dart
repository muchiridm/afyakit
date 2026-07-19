// lib/features/health_metrics/widgets/health_metric_ui.dart

import 'package:flutter/material.dart';

import '../models/health_metric_type.dart';

IconData healthMetricIcon(HealthMetricType type) {
  switch (type) {
    case HealthMetricType.bloodPressure:
      return Icons.bloodtype_outlined;

    case HealthMetricType.pulse:
      return Icons.favorite_border;

    case HealthMetricType.oxygenSaturation:
      return Icons.sensors_outlined;

    case HealthMetricType.respiratoryRate:
      return Icons.air;

    case HealthMetricType.height:
      return Icons.height;

    case HealthMetricType.weight:
      return Icons.monitor_weight_outlined;

    case HealthMetricType.waistCircumference:
      return Icons.straighten;

    case HealthMetricType.bloodGlucose:
      return Icons.water_drop_outlined;

    case HealthMetricType.temperature:
      return Icons.thermostat_outlined;
  }
}

String formatHealthMetricDateTime(DateTime value) {
  final local = value.toLocal();

  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');

  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$day/$month/${local.year} at $hour:$minute';
}

String formatHealthMetricDate(DateTime value) {
  final local = value.toLocal();

  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');

  return '$day/$month/${local.year}';
}

String formatHealthMetricTime(DateTime value) {
  final local = value.toLocal();

  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$hour:$minute';
}

String healthMetricContextLabel(String? value) {
  final raw = value?.trim();

  if (raw == null || raw.isEmpty) {
    return '—';
  }

  switch (raw) {
    case 'seated':
      return 'Seated';

    case 'standing':
      return 'Standing';

    case 'lying':
      return 'Lying down';

    case 'resting':
      return 'Resting';

    case 'post_exercise':
      return 'After exercise';

    case 'fasting':
      return 'Fasting';

    case 'random':
      return 'Random';

    case 'pre_meal':
      return 'Before meal';

    case 'post_meal':
      return 'After meal';

    case 'oral':
      return 'Oral';

    case 'axillary':
      return 'Axillary';

    case 'tympanic':
      return 'Ear';

    case 'temporal':
      return 'Temporal';

    default:
      return _titleCase(raw.replaceAll('_', ' '));
  }
}

String nullableHealthMetricText(String? value) {
  final trimmed = value?.trim();

  return trimmed == null || trimmed.isEmpty ? '—' : trimmed;
}

String _titleCase(String value) {
  return value
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) =>
            '${part[0].toUpperCase()}'
            '${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}
