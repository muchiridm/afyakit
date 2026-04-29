// lib/features/patients/services/patient_profiles_service.dart

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/features/patients/models/patient_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final patientProfilesServiceProvider = Provider<PatientProfilesService>((ref) {
  final api = ref.afyakitClient;
  final routes = ref.afyakitRoutes;

  return PatientProfilesService(api: api, routes: routes);
});

class PatientProfilesService {
  const PatientProfilesService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  static Map<String, Object?> _asMap(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) return value.cast<String, Object?>();
    throw const FormatException('Expected object map');
  }

  static List<Map<String, Object?>> _asListOfMaps(Object? value) {
    if (value is! List) return const <Map<String, Object?>>[];

    return value
        .whereType<Map>()
        .map((e) => e.cast<String, Object?>())
        .toList(growable: false);
  }

  Future<List<PatientProfile>> list({
    String? search,
    String? payerContactId,
    String? insurance,
    String? scheme,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final uri = routes.patientsList(
      search: search,
      payerContactId: payerContactId,
      insurance: insurance,
      scheme: scheme,
      isActive: isActive,
      perPage: perPage,
      page: page,
    );

    final response = await api.getUri<Object?>(uri);
    final body = _asMap(response.data);
    final rows = _asListOfMaps(body['patients']);

    return rows.map(PatientProfile.fromJson).toList(growable: false);
  }

  Future<PatientProfile> get(String patientId) async {
    final response = await api.getUri<Object?>(routes.patientGet(patientId));
    final body = _asMap(response.data);
    return PatientProfile.fromJson(_asMap(body['patient']));
  }

  Future<PatientProfile> create(PatientProfileUpsertInput input) async {
    final response = await api.postUri<Object?>(
      routes.patientCreate(),
      data: input.toJson(),
    );
    final body = _asMap(response.data);
    return PatientProfile.fromJson(_asMap(body['patient']));
  }

  Future<PatientProfile> update(
    String patientId,
    PatientProfileUpsertInput input,
  ) async {
    final response = await api.putUri<Object?>(
      routes.patientUpdate(patientId),
      data: input.toJson(),
    );
    final body = _asMap(response.data);
    return PatientProfile.fromJson(_asMap(body['patient']));
  }

  Future<void> delete(String patientId) async {
    await api.deleteUri<Object?>(routes.patientDelete(patientId));
  }
}
