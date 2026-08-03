// lib/features/clinical/profiles/profiles_service.dart

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/features/clinical/profiles/models/profile_link_request_models.dart';
import 'package:afyakit/features/clinical/profiles/models/profile_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profilesServiceProvider = Provider<ProfilesService>((ref) {
  final api = ref.afyakitClient;
  final routes = ref.afyakitRoutes;

  return ProfilesService(api: api, routes: routes);
});

final profilesServiceReadyProvider =
    FutureProvider.autoDispose<ProfilesService>((ref) async {
      final api = await ref.watch(afyakitClientFutureProvider.future);
      final routes = ref.afyakitRoutes;

      return ProfilesService(api: api, routes: routes);
    });

class ProfilesService {
  const ProfilesService({required this.api, required this.routes});

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

  static Profile _readPatient(Object? value) {
    return Profile.fromJson(_asMap(value));
  }

  static List<Profile> _readPatients(Object? value) {
    return _asListOfMaps(value).map(Profile.fromJson).toList(growable: false);
  }

  static ProfileLinkRequest _readLinkRequest(Object? value) {
    return ProfileLinkRequest.fromJson(_asMap(value));
  }

  static List<ProfileLinkRequest> _readLinkRequests(Object? value) {
    return _asListOfMaps(
      value,
    ).map(ProfileLinkRequest.fromJson).toList(growable: false);
  }

  // ─────────────────────────────────────────────
  // Profiles
  // ─────────────────────────────────────────────

  Future<List<Profile>> list({
    String? search,
    String? contactId,
    ProfileContactRelationship? relationship,
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

  Future<Profile> get(String patientId) async {
    final id = _requiredId(patientId, 'patientId');

    final response = await api.getUri<Object?>(routes.clinicalPatientGet(id));

    final body = _asMap(response.data);
    return _readPatient(body['patient']);
  }

  Future<Profile> create(ProfileUpsertInput input) async {
    final response = await api.postUri<Object?>(
      routes.clinicalPatientCreate(),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readPatient(body['patient']);
  }

  Future<Profile> update(String patientId, ProfileUpsertInput input) async {
    final id = _requiredId(patientId, 'patientId');

    final response = await api.putUri<Object?>(
      routes.clinicalPatientUpdate(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readPatient(body['patient']);
  }

  Future<Profile> linkToSelf(
    String patientId,
    ProfileLinkToSelfInput input,
  ) async {
    final id = _requiredId(patientId, 'patientId');

    final response = await api.postUri<Object?>(
      routes.clinicalPatientLinkSelf(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readPatient(body['patient']);
  }

  Future<Profile> linkPatientToSelf(
    String patientId,
    ProfileLinkToSelfInput input,
  ) {
    return linkToSelf(patientId, input);
  }

  // ─────────────────────────────────────────────
  // Staff direct patient-contact links
  // ─────────────────────────────────────────────

  Future<Profile> linkContact(
    String patientId,
    ProfileContactLinkInput input,
  ) async {
    final id = _requiredId(patientId, 'patientId');

    final response = await api.postUri<Object?>(
      routes.clinicalPatientLinkedContactCreate(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readPatient(body['patient']);
  }

  Future<Profile> linkContactToPatient({
    required String profileId,
    required ProfileContactLinkInput input,
  }) {
    return linkContact(profileId, input);
  }

  Future<Profile> delinkContact({
    required String patientId,
    required String contactId,
  }) async {
    final pid = _requiredId(patientId, 'patientId');
    final cid = _requiredId(contactId, 'contactId');

    final response = await api.deleteUri<Object?>(
      routes.clinicalPatientLinkedContactDelete(patientId: pid, contactId: cid),
    );

    final body = _asMap(response.data);
    return _readPatient(body['patient']);
  }

  Future<Profile> delinkContactFromProfile({
    required String profileId,
    required String contactId,
  }) {
    return delinkContact(patientId: profileId, contactId: contactId);
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

  Future<ProfileLinkRequest> createLinkRequest(
    String patientId,
    ProfileLinkRequestCreateInput input,
  ) async {
    final id = _requiredId(patientId, 'patientId');

    final response = await api.postUri<Object?>(
      routes.clinicalPatientLinkRequestCreate(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readLinkRequest(body['request']);
  }

  Future<List<ProfileLinkRequest>> listLinkRequests({
    ProfileLinkRequestStatus? status,
    String? profileId,
    int perPage = 50,
    int page = 1,
  }) async {
    final uri = routes.clinicalPatientLinkRequestsList(
      status: status?.wire,
      patientId: _nullable(profileId),
      perPage: perPage,
      page: page,
    );

    final response = await api.getUri<Object?>(uri);
    final body = _asMap(response.data);

    return _readLinkRequests(body['requests']);
  }

  Future<ProfileLinkRequest> approveLinkRequest(
    String requestId,
    ProfileLinkRequestApproveInput input,
  ) async {
    final id = _requiredId(requestId, 'requestId');

    final response = await api.postUri<Object?>(
      routes.clinicalPatientLinkRequestApprove(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);
    return _readLinkRequest(body['request']);
  }

  Future<ProfileLinkRequest> rejectLinkRequest(
    String requestId,
    ProfileLinkRequestRejectInput input,
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
  Future<ProfileLinkRequest> requestPayerLink(
    String patientId,
    ProfileLinkRequestCreateInput input,
  ) {
    return createLinkRequest(patientId, input);
  }

  // Convenience alias for staff-side wording.
  Future<ProfileLinkRequest> approvePayerLinkRequest(
    String requestId,
    ProfileLinkRequestApproveInput input,
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
