import 'package:flutter_test/flutter_test.dart';
import 'package:afyakit/features/records/health_metrics/models/health_metric_entry.dart';

void main() {
  final json = <String, Object?>{
    'metric_id': 'synthetic',
    'profile_id': 'p',
    'type': 'weight',
    'primary_value': 60,
    'recorded_at': '2026-01-01T00:00:00Z',
  };
  test('metric actions require backend actions and a revision', () {
    expect(HealthMetricEntry.fromJson(json).canUpdate, false);
    expect(
      HealthMetricEntry.fromJson({
        ...json,
        'allowed_actions': ['update'],
      }).canUpdate,
      false,
    );
    final entry = HealthMetricEntry.fromJson({
      ...json,
      'revision': 2,
      'allowed_actions': ['read', 'update', 'archive'],
    });
    expect(entry.canUpdate, true);
    expect(entry.canArchive, true);
    expect(entry.copyWith(primaryValue: 61).revision, 2);
    expect(entry.copyWith().canArchive, true);
  });
  test(
    'corrections transmit the exact reviewed revision and attribution reason',
    () {
      const input = HealthMetricUpdateInput(
        expectedRevision: 2,
        reason: 'Correct transcription',
        primaryValue: 61,
      );
      expect(input.toJson(), {
        'expectedRevision': 2,
        'reason': 'Correct transcription',
        'primary_value': 61.0,
      });
    },
  );
}
