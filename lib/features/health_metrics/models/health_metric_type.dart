// lib/features/health_metrics/models/health_metric_type.dart

enum HealthMetricType {
  bloodPressure,
  bloodGlucose,
  weight,
  height,
  pulse,
  respiratoryRate,
  oxygenSaturation,
  temperature,
  waistCircumference,
}

extension HealthMetricTypeX on HealthMetricType {
  String get key {
    switch (this) {
      case HealthMetricType.bloodPressure:
        return 'blood_pressure';
      case HealthMetricType.bloodGlucose:
        return 'blood_glucose';
      case HealthMetricType.weight:
        return 'weight';
      case HealthMetricType.height:
        return 'height';
      case HealthMetricType.pulse:
        return 'pulse';
      case HealthMetricType.respiratoryRate:
        return 'respiratory_rate';
      case HealthMetricType.oxygenSaturation:
        return 'oxygen_saturation';
      case HealthMetricType.temperature:
        return 'temperature';
      case HealthMetricType.waistCircumference:
        return 'waist_circumference';
    }
  }

  String get label {
    switch (this) {
      case HealthMetricType.bloodPressure:
        return 'Blood Pressure';
      case HealthMetricType.bloodGlucose:
        return 'Blood Glucose';
      case HealthMetricType.weight:
        return 'Weight';
      case HealthMetricType.height:
        return 'Height';
      case HealthMetricType.pulse:
        return 'Pulse';
      case HealthMetricType.respiratoryRate:
        return 'Respiratory Rate';
      case HealthMetricType.oxygenSaturation:
        return 'Oxygen Saturation';
      case HealthMetricType.temperature:
        return 'Temperature';
      case HealthMetricType.waistCircumference:
        return 'Waist Circumference';
    }
  }

  String get unit {
    switch (this) {
      case HealthMetricType.bloodPressure:
        return 'mmHg';
      case HealthMetricType.bloodGlucose:
        return 'mmol/L';
      case HealthMetricType.weight:
        return 'kg';
      case HealthMetricType.height:
        return 'cm';
      case HealthMetricType.pulse:
        return 'bpm';
      case HealthMetricType.respiratoryRate:
        return '/min';
      case HealthMetricType.oxygenSaturation:
        return '%';
      case HealthMetricType.temperature:
        return '°C';
      case HealthMetricType.waistCircumference:
        return 'cm';
    }
  }

  bool get hasSecondaryValue => this == HealthMetricType.bloodPressure;

  static HealthMetricType? fromKey(String? value) {
    final normalized = value?.trim().toLowerCase();

    for (final type in HealthMetricType.values) {
      if (type.key == normalized) return type;
    }

    return null;
  }
}
