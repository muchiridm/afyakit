// lib/features/clinical/patients/patient_profiles_service.dart

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/features/clinical/patients/patient_profile.dart';
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

    if (value is Map) {
      return value.map(
        (key, dynamic value) => MapEntry(key.toString(), value as Object?),
      );
    }

    throw const FormatException('Expected object map');
  }

  static List<Map<String, Object?>> _asListOfMaps(Object? value) {
    if (value is! List) return const <Map<String, Object?>>[];

    return value
        .whereType<Map>()
        .map(
          (item) => item.map(
            (key, dynamic value) => MapEntry(key.toString(), value as Object?),
          ),
        )
        .toList(growable: false);
  }

  static PatientProfile _readPatient(Object? value) {
    return PatientProfile.fromJson(_asMap(value));
  }

  static List<PatientProfile> _readPatients(Object? value) {
    return _asListOfMaps(
      value,
    ).map(PatientProfile.fromJson).toList(growable: false);
  }

  static PatientLinkRequest _readLinkRequest(Object? value) {
    return PatientLinkRequest.fromJson(_asMap(value));
  }

  static List<PatientLinkRequest> _readLinkRequests(Object? value) {
    return _asListOfMaps(
      value,
    ).map(PatientLinkRequest.fromJson).toList(growable: false);
  }

  // ─────────────────────────────────────────────
  // Patient profiles
  // ─────────────────────────────────────────────

  Future<List<PatientProfile>> list({
    String? search,
    String? contactId,
    ContactPatientRelationship? relationship,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final uri = routes.clinicalPatientsList(
      search: _nullable(search),
      contactId: _nullable(contactId),
      relationship: relationship?.name,
      isActive: isActive,
      perPage: perPage,
      page: page,
    );

    final response = await api.getUri<Object?>(uri);
    final body = _asMap(response.data);

    return _readPatients(body['patients']);
  }

  Future<PatientProfile> get(String patientId) async {
    final id = _requiredId(patientId, 'patientId');

    final response = await api.getUri<Object?>(routes.clinicalPatientGet(id));

    final body = _asMap(response.data);
    return _readPatient(body['patient']);
  }

  Future<PatientProfile> create(PatientProfileUpsertInput input) async {
    final response = await api.postUri<Object?>(
      routes.clinicalPatientCreate(),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readPatient(body['patient']);
  }

  Future<PatientProfile> update(
    String patientId,
    PatientProfileUpsertInput input,
  ) async {
    final id = _requiredId(patientId, 'patientId');

    final response = await api.putUri<Object?>(
      routes.clinicalPatientUpdate(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readPatient(body['patient']);
  }

  Future<PatientProfile> linkToSelf(
    String patientId,
    PatientProfileLinkToSelfInput input,
  ) async {
    final id = _requiredId(patientId, 'patientId');

    final response = await api.postUri<Object?>(
      routes.clinicalPatientLinkSelf(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readPatient(body['patient']);
  }

  Future<PatientProfile> linkPatientToSelf(
    String patientId,
    PatientProfileLinkToSelfInput input,
  ) {
    return linkToSelf(patientId, input);
  }

  Future<void> delete(String patientId) async {
    final id = _requiredId(patientId, 'patientId');

    await api.deleteUri<Object?>(routes.clinicalPatientDelete(id));
  }

  Future<void> remove(String patientId) {
    return delete(patientId);
  }

  // ─────────────────────────────────────────────
  // Patient link requests
  // ─────────────────────────────────────────────

  Future<PatientLinkRequest> createLinkRequest(
    String patientId,
    PatientLinkRequestCreateInput input,
  ) async {
    final id = _requiredId(patientId, 'patientId');

    final response = await api.postUri<Object?>(
      routes.clinicalPatientLinkRequestCreate(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readLinkRequest(body['request']);
  }

  Future<List<PatientLinkRequest>> listLinkRequests({
    PatientLinkRequestStatus? status,
    String? patientId,
    int perPage = 50,
    int page = 1,
  }) async {
    final uri = routes.clinicalPatientLinkRequestsList(
      status: status?.wire,
      patientId: _nullable(patientId),
      perPage: perPage,
      page: page,
    );

    final response = await api.getUri<Object?>(uri);
    final body = _asMap(response.data);

    return _readLinkRequests(body['requests']);
  }

  Future<PatientLinkRequest> approveLinkRequest(
    String requestId,
    PatientLinkRequestApproveInput input,
  ) async {
    final id = _requiredId(requestId, 'requestId');

    final response = await api.postUri<Object?>(
      routes.clinicalPatientLinkRequestApprove(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readLinkRequest(body['request']);
  }

  Future<PatientLinkRequest> rejectLinkRequest(
    String requestId,
    PatientLinkRequestRejectInput input,
  ) async {
    final id = _requiredId(requestId, 'requestId');

    final response = await api.postUri<Object?>(
      routes.clinicalPatientLinkRequestReject(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readLinkRequest(body['request']);
  }

  // Convenience alias for member-side wording.
  Future<PatientLinkRequest> requestPayerLink(
    String patientId,
    PatientLinkRequestCreateInput input,
  ) {
    return createLinkRequest(patientId, input);
  }

  // Convenience alias for staff-side wording.
  Future<PatientLinkRequest> approvePayerLinkRequest(
    String requestId,
    PatientLinkRequestApproveInput input,
  ) {
    return approveLinkRequest(requestId, input);
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  static String _requiredId(String value, String name) {
    final id = value.trim();

    if (id.isEmpty) {
      throw ArgumentError.value(value, name, '$name is empty');
    }

    return id;
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
