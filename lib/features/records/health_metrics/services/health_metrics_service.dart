// lib/features/clinical/health_metrics/services/health_metrics_service.dart

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';

import '../models/health_metric_entry.dart';
import '../models/health_metric_type.dart';

class HealthMetricsService {
  const HealthMetricsService({
    required this.api,
    required this.routes,
    required this.isCurrent,
  });

  final bool Function() isCurrent;
  void _checkCurrent() {
    if (!isCurrent()) throw StateError('Metric authorization context changed');
  }

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  Future<List<HealthMetricEntry>> listMetrics({
    required String profileId,
    HealthMetricType? type,
    DateTime? from,
    DateTime? to,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final pid = _requiredId(profileId, 'profileId');

    _checkCurrent();
    final response = await api.getUri<Object?>(
      routes.recordsProfileHealthMetricsList(
        pid,
        type: type?.key,
        isActive: isActive,
        from: from,
        to: to,
        perPage: perPage,
        page: page,
      ),
    );

    _checkCurrent();
    final body = _asMap(response.data);

    return _readMetrics(body['metrics']);
  }

  Future<List<HealthMetricEntry>> listAllMetrics({
    String? profileId,
    HealthMetricType? type,
    DateTime? from,
    DateTime? to,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    _checkCurrent();
    final response = await api.getUri<Object?>(
      routes.recordsHealthMetricsList(
        profileId: _nullable(profileId),
        type: type?.key,
        isActive: isActive,
        from: from,
        to: to,
        perPage: perPage,
        page: page,
      ),
    );

    _checkCurrent();
    final body = _asMap(response.data);

    return _readMetrics(body['metrics']);
  }

  Future<HealthMetricEntry> getMetric({
    required String profileId,
    required String metricId,
  }) async {
    final pid = _requiredId(profileId, 'profileId');

    final mid = _requiredId(metricId, 'metricId');

    _checkCurrent();
    final response = await api.getUri<Object?>(
      routes.recordsProfileHealthMetricGet(profileId: pid, metricId: mid),
    );

    _checkCurrent();
    final body = _asMap(response.data);

    return _readMetric(body['metric']);
  }

  Future<void> createMetric(HealthMetricCreateInput input) async {
    final profileId = _requiredId(input.profileId, 'profileId');

    _checkCurrent();
    await api.postUri<Object?>(
      routes.recordsProfileHealthMetricCreate(profileId),
      data: input.toJson(),
    );
    _checkCurrent();
  }

  Future<void> updateMetric({
    required String profileId,
    required String metricId,
    required HealthMetricUpdateInput input,
  }) async {
    final pid = _requiredId(profileId, 'profileId');

    final mid = _requiredId(metricId, 'metricId');

    _checkCurrent();
    await api.putUri<Object?>(
      routes.recordsProfileHealthMetricUpdate(profileId: pid, metricId: mid),
      data: input.toJson(),
    );
    _checkCurrent();
  }

  Future<void> deleteMetric({
    required int expectedRevision,
    required String reason,
    required String profileId,
    required String metricId,
  }) async {
    final pid = _requiredId(profileId, 'profileId');

    final mid = _requiredId(metricId, 'metricId');

    _checkCurrent();
    await api.deleteUri<Object?>(
      routes.recordsProfileHealthMetricDelete(profileId: pid, metricId: mid),
      data: {'expectedRevision': expectedRevision, 'reason': reason},
    );
    _checkCurrent();
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
