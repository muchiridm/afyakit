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
    final uri = routes.clinicalProfilesList(
      search: _nullable(search),
      contactId: _nullable(contactId),
      relationship: relationship?.name,
      isActive: isActive,
      perPage: perPage,
      page: page,
    );

    final response = await api.getUri<Object?>(uri);

    final body = _asMap(response.data);

    return _readProfiles(body['profiles']);
  }

  Future<Profile> get(String profileId) async {
    final id = _requiredId(profileId, 'profileId');

    final response = await api.getUri<Object?>(routes.clinicalProfileGet(id));

    final body = _asMap(response.data);

    return _readProfile(body['profile']);
  }

  Future<Profile> create(ProfileUpsertInput input) async {
    final response = await api.postUri<Object?>(
      routes.clinicalProfileCreate(),
      data: input.toJson(),
    );

    final body = _asMap(response.data);

    return _readProfile(body['profile']);
  }

  Future<Profile> update(String profileId, ProfileUpsertInput input) async {
    final id = _requiredId(profileId, 'profileId');

    final response = await api.putUri<Object?>(
      routes.clinicalProfileUpdate(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);

    return _readProfile(body['profile']);
  }

  Future<void> delete(String profileId) async {
    final id = _requiredId(profileId, 'profileId');

    await api.deleteUri<Object?>(routes.clinicalProfileDelete(id));
  }

  Future<void> remove(String profileId) {
    return delete(profileId);
  }

  // ─────────────────────────────────────────────
  // Member profile linking
  // ─────────────────────────────────────────────

  Future<Profile> linkToSelf(
    String profileId,
    ProfileLinkToSelfInput input,
  ) async {
    final id = _requiredId(profileId, 'profileId');

    final response = await api.postUri<Object?>(
      routes.clinicalProfileLinkSelf(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);

    return _readProfile(body['profile']);
  }

  // ─────────────────────────────────────────────
  // Staff direct profile-contact links
  // ─────────────────────────────────────────────

  Future<Profile> linkContact(
    String profileId,
    ProfileContactLinkInput input,
  ) async {
    final id = _requiredId(profileId, 'profileId');

    final response = await api.postUri<Object?>(
      routes.clinicalProfileLinkedContactCreate(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);

    return _readProfile(body['profile']);
  }

  Future<Profile> delinkContact({
    required String profileId,
    required String contactId,
  }) async {
    final pid = _requiredId(profileId, 'profileId');

    final cid = _requiredId(contactId, 'contactId');

    final response = await api.deleteUri<Object?>(
      routes.clinicalProfileLinkedContactDelete(profileId: pid, contactId: cid),
    );

    final body = _asMap(response.data);

    return _readProfile(body['profile']);
  }

  // ─────────────────────────────────────────────
  // Profile link requests
  // ─────────────────────────────────────────────

  Future<ProfileLinkRequest> createLinkRequest(
    String profileId,
    ProfileLinkRequestCreateInput input,
  ) async {
    final id = _requiredId(profileId, 'profileId');

    final response = await api.postUri<Object?>(
      routes.clinicalProfileLinkRequestCreate(id),
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
    final uri = routes.clinicalProfileLinkRequestsList(
      status: status?.wire,
      profileId: _nullable(profileId),
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
      routes.clinicalProfileLinkRequestApprove(id),
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
      routes.clinicalProfileLinkRequestReject(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);

    return _readLinkRequest(body['request']);
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  static Profile _readProfile(Object? value) {
    return Profile.fromJson(_asMap(value));
  }

  static List<Profile> _readProfiles(Object? value) {
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

  static Map<String, Object?> _asMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (key, dynamic value) => MapEntry(key.toString(), value as Object?),
      );
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
          (item) => item.map(
            (key, dynamic value) => MapEntry(key.toString(), value as Object?),
          ),
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
