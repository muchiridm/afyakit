// lib/features/records/health_profiles/profiles_service.dart

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/features/records/health_profiles/profile_link_request_models.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
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

  // ---------------------------------------------------------
  // Health Profiles
  // ---------------------------------------------------------

  Future<List<Profile>> list({
    String? search,
    String? accountNumber,
    ProfileContactRelationship? relationship,
    bool? isActive,
    int perPage = 50,
    int page = 1,
  }) async {
    final account = _optionalAccountNumber(
      accountNumber: accountNumber,
    );

    final uri = routes.recordsProfilesList(
      search: _nullable(search),
      accountNumber: account,
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

    final response = await api.getUri<Object?>(routes.recordsProfileGet(id));

    final body = _asMap(response.data);

    return _readProfile(body['profile']);
  }

  Future<Profile> create(ProfileUpsertInput input) async {
    final data = _profileUpsertPayload(input);

    final response = await api.postUri<Object?>(
      routes.recordsProfileCreate(),
      data: data,
    );

    final body = _asMap(response.data);

    return _readProfile(body['profile']);
  }

  Future<Profile> update(String profileId, ProfileUpsertInput input) async {
    final id = _requiredId(profileId, 'profileId');

    final data = _profileUpsertPayload(input)..remove('account_number')..remove('relationship');

    final response = await api.putUri<Object?>(
      routes.recordsProfileUpdate(id),
      data: data,
    );

    final body = _asMap(response.data);

    return _readProfile(body['profile']);
  }

  Future<void> delete(String profileId) async {
    final id = _requiredId(profileId, 'profileId');

    await api.deleteUri<Object?>(routes.recordsProfileDelete(id));
  }

  Future<void> remove(String profileId) {
    return delete(profileId);
  }

  // ---------------------------------------------------------
  // Member Profile Linking
  // ---------------------------------------------------------

  /// The backend identifies the member's canonical Native
  /// Contact through the authenticated session.
  ///
  /// The frontend must not supply another member's account.
  Future<Profile> linkToSelf(
    String profileId,
    ProfileLinkToSelfInput input,
  ) async {
    final id = _requiredId(profileId, 'profileId');

    final response = await api.postUri<Object?>(
      routes.recordsProfileLinkSelf(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);

    return _readProfile(body['profile']);
  }

  // ---------------------------------------------------------
  // Staff Profile–Native Contact Links
  // ---------------------------------------------------------

  /// Links a Health Profile to a canonical Native Contact.
  ///
  /// The account number must represent AC-XXXXXX.
  ///
  /// The backend validates Contact identity, app enrolment,
  /// relationship permissions and any required authorisation.
  Future<Profile> linkContact(
    String profileId,
    ProfileContactLinkInput input,
  ) async {
    final id = _requiredId(profileId, 'profileId');

    final account = _requiredAccountNumber(
      accountNumber: input.accountNumber,
    );

    final response = await api.postUri<Object?>(
      routes.recordsProfileLinkedContactCreate(id),
      data: <String, Object?>{
        'account_number': account,
        'relationship': input.relationship.name,
        'is_active': input.isActive,
      },
    );

    final body = _asMap(response.data);

    return _readProfile(body['profile']);
  }

  /// Deactivates the relationship between a Health Profile
  /// and a Native Contact without deleting either record.
  ///
  Future<Profile> delinkContact({
    required String profileId,
    String? accountNumber,
  }) async {
    final pid = _requiredId(profileId, 'profileId');

    final account = _requiredAccountNumber(
      accountNumber: accountNumber,
    );

    final response = await api.deleteUri<Object?>(
      routes.recordsProfileLinkedContactDelete(
        profileId: pid,
        accountNumber: account,
      ),
    );

    final body = _asMap(response.data);

    return _readProfile(body['profile']);
  }

  // ---------------------------------------------------------
  // Independent profile relationships and payer account links
  // ---------------------------------------------------------

  Future<List<RelatedProfile>> listRelatedProfiles(String profileId) async {
    final response = await api.getUri<Object?>(
      routes.recordsProfileRelationshipsList(_requiredId(profileId, 'profileId')),
    );
    final body = _asMap(response.data);
    return _asListOfMaps(body['linked_profiles'])
        .map(RelatedProfile.fromJson).toList(growable: false);
  }

  // Profile-to-profile relationships are inferred, never written.
  // To change them, staff corrects the underlying Native Contact links.

  /// Staff-only under backend v2. Do not fetch in member mode.
  Future<List<ProfileLinkedContact>> listLinkedPayers(String profileId) async {
    final response = await api.getUri<Object?>(
      routes.recordsProfileLinkedContactsList(_requiredId(profileId, 'profileId')),
    );
    return _asListOfMaps(_asMap(response.data)['linked_payers'])
        .map(ProfileLinkedContact.fromJson).toList(growable: false);
  }

  // ---------------------------------------------------------
  // Profile Link Requests
  // ---------------------------------------------------------

  Future<ProfileLinkRequest> createLinkRequest(
    String profileId,
    ProfileLinkRequestCreateInput input,
  ) async {
    final id = _requiredId(profileId, 'profileId');

    final response = await api.postUri<Object?>(
      routes.recordsProfileLinkRequestCreate(id),
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
    final uri = routes.recordsProfileLinkRequestsList(
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
      routes.recordsProfileLinkRequestApprove(id),
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
      routes.recordsProfileLinkRequestReject(id),
      data: input.toJson(),
    );

    final body = _asMap(response.data);

    return _readLinkRequest(body['request']);
  }

  // ---------------------------------------------------------
  // Native Contact Identity Helpers
  // ---------------------------------------------------------

  static final RegExp _accountNumberPattern = RegExp(
    r'^AC-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$',
  );

  static String? _optionalAccountNumber({String? accountNumber}) {
    final account = _nullable(accountNumber)?.toUpperCase();
    if (account != null && !_accountNumberPattern.hasMatch(account)) {
      throw ArgumentError.value(
        account,
        'accountNumber',
        'Expected canonical Native Contact account number (AC-XXXXXX)',
      );
    }
    return account;
  }

  static String _requiredAccountNumber({String? accountNumber}) {
    final account = _optionalAccountNumber(accountNumber: accountNumber);
    if (account == null) {
      throw ArgumentError('A Native Contact account number is required');
    }
    return account;
  }

  static Map<String, Object?> _profileUpsertPayload(ProfileUpsertInput input) {
    final data = Map<String, Object?>.from(input.toJson());
    final account = _optionalAccountNumber(accountNumber: input.accountNumber);
    if (account != null) data['account_number'] = account;
    return data;
  }

  // ---------------------------------------------------------
  // Response Helpers
  // ---------------------------------------------------------

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
