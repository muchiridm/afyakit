// lib/features/health_metrics/providers/health_metrics_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/providers.dart';

import '../models/health_metric_entry.dart';
import '../models/health_metric_type.dart';
import '../services/health_metrics_service.dart';

final healthMetricsServiceProvider = Provider<HealthMetricsService>((ref) {
  return HealthMetricsService(
    api: ref.afyakitClient,
    routes: ref.afyakitRoutes,
  );
});

final healthMetricEntriesProvider = FutureProvider.autoDispose
    .family<List<HealthMetricEntry>, HealthMetricEntriesQuery>((ref, query) {
      final service = ref.watch(healthMetricsServiceProvider);

      return service.listMetrics(
        patientId: query.patientId,
        type: query.type,
        from: query.from,
        to: query.to,
        isActive: query.isActive,
        page: query.page,
        perPage: query.perPage,
      );
    });

class HealthMetricEntriesQuery {
  const HealthMetricEntriesQuery({
    required this.patientId,
    this.type,
    this.from,
    this.to,
    this.isActive = true,
    this.page = 1,
    this.perPage = 50,
  });

  final String patientId;
  final HealthMetricType? type;
  final DateTime? from;
  final DateTime? to;
  final bool? isActive;
  final int page;
  final int perPage;

  @override
  bool operator ==(Object other) {
    return other is HealthMetricEntriesQuery &&
        other.patientId == patientId &&
        other.type == type &&
        other.from == from &&
        other.to == to &&
        other.isActive == isActive &&
        other.page == page &&
        other.perPage == perPage;
  }

  @override
  int get hashCode =>
      Object.hash(patientId, type, from, to, isActive, page, perPage);
}
