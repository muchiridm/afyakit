// lib/features/health_metrics/services/health_metrics_service.dart

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';

import '../models/health_metric_entry.dart';
import '../models/health_metric_type.dart';

class HealthMetricsService {
  const HealthMetricsService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  Future<List<HealthMetricEntry>> listMetrics({
    required String patientId,
    HealthMetricType? type,
    DateTime? from,
    DateTime? to,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final pid = _requiredId(patientId, 'patientId');

    final response = await api.getUri<Object?>(
      routes.healthMetricsForPatient(
        pid,
        type: type?.key,
        isActive: isActive,
        from: from,
        to: to,
        perPage: perPage,
        page: page,
      ),
    );

    final body = _asMap(response.data);

    return _readMetrics(body['metrics']);
  }

  Future<List<HealthMetricEntry>> listAllMetrics({
    String? patientId,
    HealthMetricType? type,
    DateTime? from,
    DateTime? to,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final response = await api.getUri<Object?>(
      routes.healthMetrics(
        patientId: _nullable(patientId),
        type: type?.key,
        isActive: isActive,
        from: from,
        to: to,
        perPage: perPage,
        page: page,
      ),
    );

    final body = _asMap(response.data);

    return _readMetrics(body['metrics']);
  }

  Future<HealthMetricEntry> getMetric({
    required String patientId,
    required String metricId,
  }) async {
    final pid = _requiredId(patientId, 'patientId');

    final mid = _requiredId(metricId, 'metricId');

    final response = await api.getUri<Object?>(routes.healthMetric(pid, mid));

    final body = _asMap(response.data);

    return _readMetric(body['metric']);
  }

  Future<HealthMetricEntry> createMetric(HealthMetricCreateInput input) async {
    final patientId = _requiredId(input.patientId, 'patientId');

    final response = await api.postUri<Object?>(
      routes.healthMetricsForPatient(patientId),
      data: input.toJson(),
    );

    final body = _asMap(response.data);

    return _readMetric(body['metric']);
  }

  Future<HealthMetricEntry> updateMetric({
    required String patientId,
    required String metricId,
    required HealthMetricUpdateInput input,
  }) async {
    final pid = _requiredId(patientId, 'patientId');

    final mid = _requiredId(metricId, 'metricId');

    final response = await api.putUri<Object?>(
      routes.healthMetric(pid, mid),
      data: input.toJson(),
    );

    final body = _asMap(response.data);

    return _readMetric(body['metric']);
  }

  Future<void> deleteMetric({
    required String patientId,
    required String metricId,
  }) async {
    final pid = _requiredId(patientId, 'patientId');

    final mid = _requiredId(metricId, 'metricId');

    await api.deleteUri<Object?>(routes.healthMetric(pid, mid));
  }

  static HealthMetricEntry _readMetric(Object? value) {
    return HealthMetricEntry.fromJson(_asMap(value));
  }

  static List<HealthMetricEntry> _readMetrics(Object? value) {
    return _asListOfMaps(
      value,
    ).map(HealthMetricEntry.fromJson).toList(growable: false);
  }

  static Map<String, Object?> _asMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }

    throw const FormatException('Expected object map');
  }

  static List<Map<String, Object?>> _asListOfMaps(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList(growable: false);
  }

  static String _requiredId(String value, String name) {
    final id = value.trim();

    if (id.isEmpty) {
      throw ArgumentError.value(value, name, '$name is empty');
    }

    return id;
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();

    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
