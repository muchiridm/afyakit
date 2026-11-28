import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_form_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/health_profiles/profiles_service.dart';
import 'package:afyakit/features/records/health_metrics/services/health_metrics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('demographic form does not render confidential history fields', (
    tester,
  ) async {
    const profile = Profile(
      profileId: 'p',
      fullName: 'Synthetic',
      isActive: true,
      notes: 'LEGACY_CONFIDENTIAL',
    );
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ProfileFormDialog(initial: profile)),
        ),
      ),
    );
    expect(find.text('Known allergies'), findsNothing);
    expect(find.text('LEGACY_CONFIDENTIAL'), findsNothing);
    expect(find.text('Full name'), findsOneWidget);
  });
  testWidgets('personal history form seeds only new self-reported history', (
    tester,
  ) async {
    const profile = Profile(
      profileId: 'p',
      fullName: 'Synthetic',
      isActive: true,
      pastMedicalHistory: 'LEGACY_CONFIDENTIAL',
      selfReportedHistory: {'past_medical_history': 'PERSONAL_STATEMENT'},
    );
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ProfileFormDialog(initial: profile, historyOnly: true),
          ),
        ),
      ),
    );
    expect(find.text('LEGACY_CONFIDENTIAL'), findsNothing);
    expect(find.text('PERSONAL_STATEMENT'), findsOneWidget);
    expect(find.text('Full name'), findsNothing);
  });
  test('omitted clinical history is unavailable, not an empty history', () {
    final reference = Profile.fromJson({
      'profile_id': 'p',
      'full_name': 'Synthetic',
      'projection': 'reference',
      'is_active': true,
    });
    expect(reference.clinicalAvailable, false);
    expect(reference.allows('records.profile.demographics.update'), false);
    final own = Profile.fromJson({
      'profile_id': 'p',
      'full_name': 'Synthetic',
      'projection': 'personal',
      'is_active': true,
      'allowed_actions': ['records.profile.history.update'],
      'self_reported_history': {'notes': 'Self reported'},
    });
    expect(own.clinicalAvailable, true);
    expect(
      own
          .copyWith(fullName: 'Changed')
          .allows('records.profile.history.update'),
      true,
    );
    expect(own.selfReportedHistory['notes'], 'Self reported');
  });
  test('demographic and self-reported history payloads do not mix', () {
    const input = ProfileUpsertInput(
      fullName: 'Synthetic',
      notes: 'History',
      allergyStatus: AllergyStatus.none_known,
    );
    expect(input.demographicJson().containsKey('notes'), false);
    expect(input.historyJson().containsKey('full_name'), false);
    expect(input.historyJson()['notes'], 'History');
  });
  test(
    'personal history uses separate operation and committed acknowledgement',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(request.path.endsWith('/clinical-history'), true);
            expect((request.data as Map).containsKey('full_name'), false);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {'ok': true, 'profile_id': 'p'},
              ),
            );
          },
        ),
      );
      final service = ProfilesService(
        api: AfyaKitClient(dio),
        routes: AfyaKitRoutes('demo'),
        isCurrent: () => true,
      );
      await service.updatePersonalHistory(
        'p',
        const ProfileUpsertInput(fullName: 'Synthetic', notes: 'Personal'),
      );
    },
  );
  test(
    'stale clinical metric response is rejected after context changes',
    () async {
      var current = true;
      final pending = Completer<void>();
      final started = Completer<void>();
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            started.complete();
            await pending.future;
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {'metrics': []},
              ),
            );
          },
        ),
      );
      final service = HealthMetricsService(
        api: AfyaKitClient(dio),
        routes: AfyaKitRoutes('demo'),
        isCurrent: () => current,
      );
      final result = service.listMetrics(profileId: 'p');
      await started.future;
      current = false;
      final expectation = expectLater(result, throwsStateError);
      pending.complete();
      await expectation;
    },
  );
}
