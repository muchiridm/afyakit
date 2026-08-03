// lib/core/api/afyakit/routes/routes_health_metrics.dart

part of 'routes.dart';

extension AfyaKitHealthMetricsRoutes on AfyaKitRoutes {
  static const String _healthMetricsBase = 'health_metrics';

  Uri healthMetricsForPatient(
    String patientId, {
    String? type,
    bool? isActive,
    DateTime? from,
    DateTime? to,
    int? page,
    int? perPage,
  }) {
    return _uri(
      '$_healthMetricsBase/patients/'
      '${_seg(patientId)}/metrics',
      query: _healthMetricsQuery(
        type: type,
        isActive: isActive,
        from: from,
        to: to,
        page: page,
        perPage: perPage,
      ),
    );
  }

  Uri healthMetric(String patientId, String metricId) {
    return _uri(
      '$_healthMetricsBase/patients/'
      '${_seg(patientId)}/metrics/'
      '${_seg(metricId)}',
    );
  }

  Uri healthMetrics({
    String? patientId,
    String? type,
    bool? isActive,
    DateTime? from,
    DateTime? to,
    int? page,
    int? perPage,
  }) {
    return _uri(
      '$_healthMetricsBase/metrics',
      query: _healthMetricsQuery(
        patientId: patientId,
        type: type,
        isActive: isActive,
        from: from,
        to: to,
        page: page,
        perPage: perPage,
      ),
    );
  }

  Map<String, String>? _healthMetricsQuery({
    String? patientId,
    String? type,
    bool? isActive,
    DateTime? from,
    DateTime? to,
    int? page,
    int? perPage,
  }) {
    final query = <String, String>{};

    final cleanPatientId = patientId?.trim();
    if (cleanPatientId != null && cleanPatientId.isNotEmpty) {
      query['patient_id'] = cleanPatientId;
    }

    final cleanType = type?.trim();
    if (cleanType != null && cleanType.isNotEmpty) {
      query['type'] = cleanType;
    }

    if (isActive != null) {
      query['is_active'] = isActive.toString();
    }

    if (from != null) {
      query['from'] = from.toUtc().toIso8601String();
    }

    if (to != null) {
      query['to'] = to.toUtc().toIso8601String();
    }

    if (page != null && page > 0) {
      query['page'] = page.toString();
    }

    if (perPage != null && perPage > 0) {
      query['per_page'] = perPage.toString();
    }

    return query.isEmpty ? null : query;
  }
}
