// lib/features/health_metrics/models/health_metric_entry.dart

import 'health_metric_type.dart';

class HealthMetricEntry {
  const HealthMetricEntry({
    required this.metricId,
    required this.patientId,
    required this.type,
    required this.recordedAt,
    required this.primaryValue,
    this.secondaryValue,
    this.context,
    this.notes,
    this.recordedByUid,
    this.createdAt,
    this.updatedAt,
  });

  final String metricId;
  final String patientId;

  final HealthMetricType type;
  final DateTime recordedAt;

  /// Main value.
  ///
  /// Examples:
  /// - systolic blood pressure
  /// - weight
  /// - blood glucose
  /// - pulse
  final double primaryValue;

  /// Optional secondary value.
  ///
  /// Currently used for diastolic blood pressure.
  final double? secondaryValue;

  /// Optional structured context such as:
  /// fasting, random, seated, resting, pre-exercise, post-exercise.
  final String? context;

  final String? notes;
  final String? recordedByUid;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayValue {
    if (type == HealthMetricType.bloodPressure && secondaryValue != null) {
      return '${_format(primaryValue)}/${_format(secondaryValue!)} '
          '${type.unit}';
    }

    return '${_format(primaryValue)} ${type.unit}';
  }

  factory HealthMetricEntry.fromJson(Map<String, Object?> json) {
    final type = HealthMetricTypeX.fromKey(json['type']?.toString());

    if (type == null) {
      throw FormatException('Unsupported health metric type: ${json['type']}');
    }

    return HealthMetricEntry(
      metricId: _readString(json, 'metric_id'),
      patientId: _readString(json, 'patient_id'),
      type: type,
      recordedAt: _readRequiredDateTime(json, 'recorded_at'),
      primaryValue: _readRequiredDouble(json, 'primary_value'),
      secondaryValue: _readNullableDouble(json, 'secondary_value'),
      context: _readNullableString(json, 'context'),
      notes: _readNullableString(json, 'notes'),
      recordedByUid: _readNullableString(json, 'recorded_by_uid'),
      createdAt: _readNullableDateTime(json, 'created_at'),
      updatedAt: _readNullableDateTime(json, 'updated_at'),
    );
  }

  HealthMetricEntry copyWith({
    String? metricId,
    String? patientId,
    HealthMetricType? type,
    DateTime? recordedAt,
    double? primaryValue,
    double? secondaryValue,
    bool clearSecondaryValue = false,
    String? context,
    bool clearContext = false,
    String? notes,
    bool clearNotes = false,
    String? recordedByUid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HealthMetricEntry(
      metricId: metricId ?? this.metricId,
      patientId: patientId ?? this.patientId,
      type: type ?? this.type,
      recordedAt: recordedAt ?? this.recordedAt,
      primaryValue: primaryValue ?? this.primaryValue,
      secondaryValue: clearSecondaryValue
          ? null
          : secondaryValue ?? this.secondaryValue,
      context: clearContext ? null : context ?? this.context,
      notes: clearNotes ? null : notes ?? this.notes,
      recordedByUid: recordedByUid ?? this.recordedByUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _readString(
    Map<String, Object?> json,
    String key, {
    String fallback = '',
  }) {
    final value = json[key];
    if (value == null) return fallback;

    return value.toString().trim();
  }

  static String? _readNullableString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;

    final string = value.toString().trim();
    return string.isEmpty ? null : string;
  }

  static double _readRequiredDouble(Map<String, Object?> json, String key) {
    final value = json[key];

    if (value is num) {
      return value.toDouble();
    }

    final parsed = double.tryParse(value?.toString().trim() ?? '');

    if (parsed == null) {
      throw FormatException('Invalid required numeric field: $key');
    }

    return parsed;
  }

  static double? _readNullableDouble(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString().trim());
  }

  static DateTime _readRequiredDateTime(Map<String, Object?> json, String key) {
    final value = _readNullableDateTime(json, key);

    if (value == null) {
      throw FormatException('Invalid required date field: $key');
    }

    return value;
  }

  static DateTime? _readNullableDateTime(
    Map<String, Object?> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString().trim());
  }

  static String _format(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}

class HealthMetricCreateInput {
  const HealthMetricCreateInput({
    required this.patientId,
    required this.type,
    required this.recordedAt,
    required this.primaryValue,
    this.secondaryValue,
    this.context,
    this.notes,
  });

  final String patientId;
  final HealthMetricType type;
  final DateTime recordedAt;

  final double primaryValue;
  final double? secondaryValue;

  final String? context;
  final String? notes;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'patient_id': patientId,
      'type': type.key,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'primary_value': primaryValue,
      if (secondaryValue != null) 'secondary_value': secondaryValue,
      if (_nullable(context) != null) 'context': _nullable(context),
      if (_nullable(notes) != null) 'notes': _nullable(notes),
    };
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class HealthMetricUpdateInput {
  const HealthMetricUpdateInput({
    this.recordedAt,
    this.primaryValue,
    this.secondaryValue,
    this.clearSecondaryValue = false,
    this.context,
    this.clearContext = false,
    this.notes,
    this.clearNotes = false,
  });

  final DateTime? recordedAt;

  final double? primaryValue;
  final double? secondaryValue;
  final bool clearSecondaryValue;

  final String? context;
  final bool clearContext;

  final String? notes;
  final bool clearNotes;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (recordedAt != null)
        'recorded_at': recordedAt!.toUtc().toIso8601String(),
      if (primaryValue != null) 'primary_value': primaryValue,
      if (clearSecondaryValue)
        'secondary_value': null
      else if (secondaryValue != null)
        'secondary_value': secondaryValue,
      if (clearContext)
        'context': null
      else if (_nullable(context) != null)
        'context': _nullable(context),
      if (clearNotes)
        'notes': null
      else if (_nullable(notes) != null)
        'notes': _nullable(notes),
    };
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
